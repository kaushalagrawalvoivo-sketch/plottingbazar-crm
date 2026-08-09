// Supabase Edge Function: admin-users
//
// Handles creating, updating and deleting real login accounts for the
// "Manage users" screen in the PlottingBazaar CRM app.
//
// WHY THIS HAS TO BE A SERVER-SIDE FUNCTION:
// Creating/deleting a Supabase Auth user requires the project's SERVICE
// ROLE key. That key must never be shipped inside the Flutter app (APK/IPA/
// web bundle) because anyone could extract it and get full, unrestricted
// access to the entire database. This function keeps the service role key
// on the server and only exposes three narrow actions (create/update/
// delete a user), and only to callers who are already an admin or manager.
//
// DEPLOY THIS ONCE with the Supabase CLI from the project root:
//   supabase functions deploy admin-users --project-ref <your-project-ref>
// No manual secrets to set — SUPABASE_URL, SUPABASE_ANON_KEY and
// SUPABASE_SERVICE_ROLE_KEY are provided automatically to every Edge
// Function by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ALLOWED_ROLES = ["admin", "manager", "sales", "telecaller"];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization header." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Client scoped to the CALLER's own JWT — used only to confirm who is
    // actually calling this function. Never used for privileged writes.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();
    if (userError || !user) {
      return json({ error: "Invalid or expired session." }, 401);
    }

    // Admin client with the service role key. This is the only client that
    // can create/delete auth users or bypass RLS, and it never leaves this
    // server-side function.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: callerProfile, error: profileError } = await adminClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    if (
      profileError ||
      !callerProfile ||
      !["admin", "manager"].includes(callerProfile.role)
    ) {
      return json(
        { error: "Only admins or managers can manage users." },
        403,
      );
    }

    const body = await req.json();
    const action = body?.action;

    // ---------------------------------------------------------------
    // CREATE a brand-new employee login.
    // ---------------------------------------------------------------
    if (action === "create") {
      const email = (body.email ?? "").toString().trim();
      const password = (body.password ?? "").toString();
      const fullName = (body.fullName ?? "").toString().trim();
      const role = (body.role ?? "").toString();

      if (!email || !password || !role) {
        return json(
          { error: "Email, password and role are required." },
          400,
        );
      }
      if (password.length < 6) {
        return json(
          { error: "Password must be at least 6 characters." },
          400,
        );
      }
      if (!ALLOWED_ROLES.includes(role)) {
        return json({ error: "Invalid role." }, 400);
      }

      const { data: created, error: createError } = await adminClient.auth
        .admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: fullName },
        });

      if (createError || !created.user) {
        return json(
          { error: createError?.message ?? "Could not create user." },
          400,
        );
      }

      // A DB trigger auto-creates the profiles row with a default role;
      // update it to whatever role the admin actually picked.
      const { error: roleError } = await adminClient
        .from("profiles")
        .update({ role, full_name: fullName })
        .eq("id", created.user.id);

      if (roleError) {
        return json({ error: roleError.message }, 400);
      }

      return json({ id: created.user.id });
    }

    // ---------------------------------------------------------------
    // UPDATE an existing user's name / role / password.
    // ---------------------------------------------------------------
    if (action === "update") {
      const userId = (body.userId ?? "").toString();
      const fullName = body.fullName as string | undefined;
      const role = body.role as string | undefined;
      const password = body.password as string | undefined;

      if (!userId) return json({ error: "userId is required." }, 400);
      if (role && !ALLOWED_ROLES.includes(role)) {
        return json({ error: "Invalid role." }, 400);
      }
      if (password && password.length < 6) {
        return json(
          { error: "Password must be at least 6 characters." },
          400,
        );
      }

      if (password) {
        const { error: pwError } = await adminClient.auth.admin
          .updateUserById(userId, { password });
        if (pwError) return json({ error: pwError.message }, 400);
      }

      const patch: Record<string, unknown> = {};
      if (fullName !== undefined) patch.full_name = fullName;
      if (role !== undefined) patch.role = role;

      if (Object.keys(patch).length > 0) {
        const { error: updateError } = await adminClient
          .from("profiles")
          .update(patch)
          .eq("id", userId);
        if (updateError) return json({ error: updateError.message }, 400);
      }

      return json({ success: true });
    }

    // ---------------------------------------------------------------
    // DELETE a user's login entirely (removes auth user; the profiles
    // row is removed automatically via ON DELETE CASCADE).
    // ---------------------------------------------------------------
    if (action === "delete") {
      const userId = (body.userId ?? "").toString();
      if (!userId) return json({ error: "userId is required." }, 400);
      if (userId === user.id) {
        return json({ error: "You cannot delete your own account." }, 400);
      }

      // Before deleting the auth user, reassign/clear every row anywhere
      // in the database that still points at them (leads, call logs,
      // feedback, activity, etc.). Without this, Postgres rejects the
      // delete with a generic "Database error deleting user" the moment
      // any table has a foreign key to this user that isn't already
      // ON DELETE CASCADE/SET NULL -- see the
      // 20260811_admin_delete_user_prep.sql migration for the full
      // explanation. Reassigning to the admin performing the deletion
      // (instead of just deleting those rows) keeps the history intact.
      const { error: prepError } = await adminClient.rpc(
        "admin_delete_user_prep",
        { target_user_id: userId, fallback_user_id: user.id },
      );
      if (prepError) {
        return json(
          {
            error:
              `Could not reassign this user's records before deleting: ${prepError.message}. ` +
              "Make sure the 20260811_admin_delete_user_prep.sql migration has been run.",
          },
          400,
        );
      }

      const { error: deleteError } = await adminClient.auth.admin
        .deleteUser(userId);
      if (deleteError) return json({ error: deleteError.message }, 400);

      return json({ success: true });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
