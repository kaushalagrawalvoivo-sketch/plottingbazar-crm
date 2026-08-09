# PlottingBazaar CRM

Internal, private CRM for the PlottingBazaar sales team — built with
Flutter (deployed as a **PWA only**, no APK) and Supabase (Postgres +
Auth + Realtime) as the backend. No paid third-party APIs are used
anywhere in this project.

---

## 1. What this CRM does

- Admin adds leads / customers and **assigns** them to specific sales
  employees.
- A sales employee only ever sees **their own assigned** leads and
  customers — enforced at the database level (Supabase Row Level
  Security), not just hidden in the UI.
- Every call made from the app can be **logged** (outcome, duration,
  notes) against the lead.
- **Feedback / follow-up notes** are recorded per lead, with an optional
  next follow-up date.
- **Follow-up reminders** — local notifications remind the assigned
  employee about due follow-ups.
- **Call & WhatsApp** — one tap opens the phone dialer or WhatsApp chat
  (pre-filled text) for a lead, no paid API required.
- **Send photo / video / audio / any file over WhatsApp** — uses the
  device's native share sheet (see the important note in section 4).
- **Admin live activity monitor** — a real-time feed showing every call
  logged, feedback added, lead assigned, WhatsApp opened, etc., across
  the whole team, updating instantly without refreshing.
- Full **CRUD** (create / read / update / delete) on leads, customers,
  bookings, and plots.
- Deployed as a **PWA** — installable from the browser on any device,
  no Play Store / APK needed.

---

## 2. Tech stack

| Layer          | Choice                                   |
|----------------|-------------------------------------------|
| Frontend       | Flutter (Web/PWA build)                   |
| State mgmt     | Riverpod                                  |
| Backend        | Supabase (Postgres, Auth, Realtime, RLS)  |
| Calling        | `tel:` deep link (native dialer)          |
| WhatsApp text  | `wa.me` deep link (pre-filled message)    |
| WhatsApp media | Native OS share sheet (`share_plus`)      |
| Hosting        | Vercel                                    |

---

## 3. Project setup

```bash
flutter pub get
```

1. Open `lib/core/constants/supabase_constants.dart` and confirm the
   Supabase project URL + publishable (anon) key are correct. **Never**
   put the Supabase *service role* key anywhere in this app — only the
   public anon key belongs on the client.
2. In the Supabase SQL editor, run the migrations **in order**:
   1. `supabase/20260713_lead_assignment.sql` (existing — leads table,
      roles, lead assignment RLS)
   2. `supabase/20260808_crm_upgrade.sql` **(new — run this to enable
      everything added in this update)**:
      - `call_logs` table + RLS
      - `lead_feedback` table + RLS
      - `activity_log` table + RLS + realtime publication (powers the
        live monitor)
      - `assigned_to` column added to `customers` + RLS scoping
      - RLS scoping on `bookings` (via the customer's `assigned_to`)
      - RLS scoping on `plots` / `sites` (everyone can read, only admin
        can write — needed since sales staff must see inventory to
        book against it)
   3. `supabase/20260809_professional_features.sql` **(new — run this
      too)**:
      - `source` column added to `leads`
      - `check_lead_phone_exists()` function (powers duplicate-phone
        detection)
      - Lets each user update their own display name, with a trigger
        that blocks any attempt to self-assign the `admin` role
   4. `supabase/20260810_roles_and_features.sql` **(new — run this
      too)**:
      - Widens `profiles.role` to 4 values: `admin`, `manager`,
        `sales`, `telecaller`
      - `purpose` and `budget` columns added to `leads`
      - Every "admin-only" RLS policy is widened to "admin or manager"
      - New delete policies: Sales can delete their own leads/
        customers; Telecaller explicitly cannot (no delete policy
        exists for that role)
3. Existing customers created **before** this migration will have
   `assigned_to = NULL`. An admin should open each one (Customers →
   Edit) and assign it to the right salesperson, otherwise it will only
   be visible to admins until assigned.
4. Run locally:
   ```bash
   flutter run -d chrome
   ```
5. Build for production:
   ```bash
   flutter build web --release
   ```

---

## 4. Important: free-tier WhatsApp limitation (please read)

WhatsApp's official Business API is **paid**. Since this project must
stay on free methods, the app uses two different techniques depending
on what's being sent:

- **Text messages** — `wa.me` link. This opens WhatsApp with the
  message pre-filled. Fully automatic, works great.
- **Photos / videos / audio / documents** — `wa.me` **cannot** attach
  media, full stop; that is a WhatsApp restriction with no free
  workaround. Instead, the app opens the device's native **Share**
  sheet with the picked file(s) attached. The user then taps
  **WhatsApp** in that sheet, and **manually picks the contact** inside
  WhatsApp. The CRM cannot pre-select the recipient for a media share —
  only a paid WhatsApp Business API integration can do that.

This is documented here so there's no surprise later: media sending
**works**, but the last "pick the contact" step is manual, by design of
the free approach.

---

## 5. Roles & data access

Four roles, managed in **Manage Users** (Admin/Manager only):

- **Admin** and **Manager** are functionally identical — full access to
  everything, including managing users. Manager exists purely as a
  separate job-title label for reporting; it does not have reduced
  permissions anywhere.
- **Sales** — sees and can act on only their own assigned leads and
  customers, including deleting them.
- **Telecaller** — same assigned-only visibility as Sales (can call,
  log calls, add feedback, change status), but **cannot delete** leads
  or customers. This is enforced at the database level (see the new
  RLS policies in `20260810_roles_and_features.sql`), not just hidden
  in the UI — a telecaller calling the API directly still can't delete.

| Data          | Admin / Manager   | Sales                          | Telecaller                     |
|---------------|--------------------|---------------------------------|----------------------------------|
| Leads         | All, full CRUD    | Own assigned, full CRUD          | Own assigned, no delete          |
| Customers     | All, full CRUD    | Own assigned, full CRUD          | Own assigned, no delete          |
| Bookings      | All                | Only for their own customers    | Only for their own customers    |
| Plots / Sites | All (full CRUD)   | Read-only (needed for bookings) | Read-only (needed for bookings) |
| Call logs     | All                | Only for their own assigned leads | Only for their own assigned leads |
| Feedback      | All                | Only for their own assigned leads | Only for their own assigned leads |
| Activity feed / Leaderboard / Manage Users | Yes | No | No |

This is enforced with Postgres Row Level Security (RLS) policies, so
even a modified/compromised client can't bypass it — the restriction
lives in the database, not just the app's UI. A database trigger also
blocks any non-admin/manager from granting themselves a higher role,
even by calling the update API directly.

---

## 6. Where everything lives (for future changes)

```
lib/
  models/            call_log_model.dart, lead_feedback_model.dart,
                      activity_log_model.dart, customer_model.dart (now
                      has assignedTo), lead_model.dart, ...
  core/services/      call_log_service.dart, feedback_service.dart,
                      activity_service.dart, contact_action_service.dart
                      (call / WhatsApp text / WhatsApp media)
  providers/          lead_provider.dart, customer_provider.dart
                      (both now log to activity_log automatically)
  screens/leads/      edit_lead_screen.dart — the main "lead detail"
                      hub: edit fields, Call, WhatsApp text, WhatsApp
                      media, log-a-call sheet, add feedback, full
                      history timeline. Every other screen that opens a
                      lead links here, so it's the single source of
                      truth for a lead's activity.
  screens/customers/  add_customer_screen.dart / edit_customer_screen.dart
                      — now include an "Assign to" picker (admin only;
                      sales users auto-assign to themselves)
  screens/admin/      activity_monitor_screen.dart — the real-time
                      admin monitoring feed; leaderboard_screen.dart —
                      employee performance ranking
  screens/profile/    profile_screen.dart — edit your name, change
                      your password
supabase/
  20260713_lead_assignment.sql        (existing)
  20260808_crm_upgrade.sql            (batch 1 — see section 3)
  20260809_professional_features.sql  (batch 2 — see section 3)
  20260810_roles_and_features.sql     (batch 3 — see section 3)
```

---

## 7. What changed in this update

- Removed `netlify.toml` — **Vercel is now the only deployment
  target**. `vercel.json` was already correctly configured for the
  Flutter web build and needed no changes.
- Replaced the app icon, favicon, maskable icons, and in-app splash
  logo with the actual PlottingBazaar logo (transparent background,
  correctly padded for both regular and maskable PWA icon slots).
- Added call logging, feedback/follow-up history, and a merged timeline
  on the lead detail screen.
- Added free-method WhatsApp media sharing (image/video/audio/any
  file).
- Added an admin-only real-time activity monitor.
- Scoped `customers` and `bookings` to the assigned employee the same
  way `leads` already were (previously only leads were scoped — this
  was a gap, now closed).
- Added an "Assign to" picker on customer create/edit so admins can
  hand off customers exactly like leads.
- Added a reliable, in-app **"Install App" button** and a centralized,
  **customizable app theme** (see sections 9 and 10 below).
- Added a full round of professional CRM features — see section 8.
- Added 4 roles, lead purpose/budget fields, bottom-navigation, and
  compact lead tiles — see section 8a.

## 8. Professional features added

All of these are built entirely on the existing free stack (Supabase +
Flutter) — no paid API or third-party service was introduced.

- **Duplicate phone detection** — when adding a lead, the app checks
  (via a database function, so it works even across employees whose
  data is normally scoped away from each other) whether that phone
  number is already a lead anywhere in the system, and warns with the
  existing lead's name/status/assignee before letting you proceed.
  This is the single most common real-world CRM mess — two employees
  independently calling the same person — and it's now caught at entry.
- **Lead source tracking** — every lead can be tagged with where it
  came from (Facebook, Instagram, Google Ads, Referral, Walk-in,
  Website, Newspaper, Other). Shown on Add/Edit Lead, included in CSV
  import/export, and summarized on the Reports screen ("Leads by
  source") so you can see which channel is actually converting.
- **Employee performance leaderboard** (admin-only) — ranks every
  sales employee by calls made this week, total calls, leads assigned,
  and leads converted (booked). Answers "who is actually working the
  leads" at a glance instead of digging through individual histories.
- **Overdue follow-up highlighting** — a lead whose follow-up date has
  passed (and isn't already Booked/Lost) is now flagged in red with a
  warning icon on its card, and the dashboard has a dedicated red
  "Overdue follow-ups" counter so nothing quietly slips through.
- **Profile & account self-service** — every user (not just admin) can
  now open **My profile** to edit their own display name and change
  their own password, without needing an admin to do it for them.
  Role changes remain admin-only, enforced by a database trigger (not
  just hidden in the UI), so a sales user can't grant themselves admin
  even by calling the API directly.

## 8a. Roles, lead details, and navigation overhaul

- **Four roles** — `admin`, `manager`, `sales`, `telecaller`. Manager
  is a full second admin tier (same permissions, including Manage
  Users) — it exists purely as a separate job title for reporting.
  Telecaller has the same assigned-only visibility as Sales but cannot
  delete leads or customers (enforced in the database, not just the
  UI — see section 5).
- **Purpose & Budget on leads** — Add/Edit Lead now has a Purpose
  dropdown (Investment, Self Use, Resale, Commercial, Agricultural,
  Other) and a Budget field (₹). Both are included in CSV export.
- **Assignable-user pickers now only show Sales/Telecaller** — the
  "Assign to" dropdowns on leads and customers used to list every
  profile including Admin/Manager; they're now filtered so a lead can
  only be handed to actual field staff.
- **Bottom navigation dock** replaces the side drawer — Home, Leads,
  Customers, Reminders, and More (Inventory, Sites, Bookings, Reports,
  and the admin/manager-only screens) are now one tap away at the
  bottom of the screen, which is easier to reach one-handed on mobile
  than a side drawer.
- **Dashboard tiles are now tappable** — tapping "New", "Follow-ups",
  "Booked", or "Overdue follow-ups" jumps straight into the Leads list
  pre-filtered to that exact view.
- **Compact lead list** — each lead is now a single, short row (name,
  phone, site, status) instead of a tall card with all its buttons
  showing — noticeably more leads fit on a phone screen at once.
  Tapping a row opens a bottom sheet with every action (view details,
  call, WhatsApp, delete-if-permitted) instead of dedicated buttons
  cluttering the row.

## 9. Fixing the PWA install popup

Browsers show their own install prompt on their own schedule — Chrome
in particular waits for "engagement heuristics" (repeat visits, time
on page) before it shows anything automatically, so it can look like
install "isn't working" when really it's just being slow/inconsistent.
Two things were fixed here:

1. **`web/manifest.json`** — added the `id` and `categories` fields and
   made sure `theme_color` matches the actual brand color everywhere
   (previously it was a mismatched blue).
2. **A real "Install App" button** — `web/index.html` now captures the
   browser's `beforeinstallprompt` event itself the moment it fires,
   and `lib/widgets/pwa_install_banner.dart` shows a dismissible banner
   on the dashboard with an **Install** button that triggers it
   directly. This does not depend on the browser's own timing.
   - On iOS Safari (which never fires that browser event, by Apple's
     design — there is no workaround), tapping Install shows a dialog
     with manual "Share → Add to Home Screen" instructions instead.
   - The banner automatically hides itself once the app is already
     installed (detected via `display-mode: standalone`).

If it still doesn't show a button: the site must be served over
**HTTPS** (Vercel does this automatically) and the manifest/icons must
load with a **200 status**, not be swallowed by a catch-all rewrite —
double-check `vercel.json`'s `rewrites` aren't intercepting
`/manifest.json` or `/icons/*` if you ever change that file.

## 10. Making the app your own (branding & theme)

Everything visual is centralized in **`lib/core/theme/app_theme.dart`**:

- Change `AppTheme.brandColor` to re-theme every button, chip, and
  accent color across the entire app in one edit.
- Card corner radius, input field style, button padding, snackbar
  shape, etc. are all defined once in that same file.
- The app name shown to users is in `lib/app.dart` (`title:`) and in
  `web/manifest.json` (`name` / `short_name`) — update both if you
  rename the product.
- To swap the logo/icon again later, replace
  `assets/images/logo.png` (splash screen) and the four files in
  `web/icons/` + `web/favicon.png` (PWA icons), keeping the same file
  names and sizes (192×192, 512×512, plus maskable variants).

## 11. Known limitations / good next steps

- Bulk-assign for customers (like the existing bulk-assign on the
  Leads screen) isn't built yet — customers are assigned one at a time
  via Edit Customer. Worth adding if the customer list grows large.
- Local follow-up notifications are per-device; if an employee doesn't
  open the app on a given day, they won't see that day's reminder until
  they do. A server-side push (still free via Supabase Edge Functions +
  Web Push) would make this fully reliable, but wasn't in scope here.
- No automated tests were added for the new tables/services.
- `lib/core/services/pwa_install_service.dart` uses `dart:js_interop`,
  which only compiles for the web target. Since this app is built with
  `flutter build web` only (by design — PWA, not APK), that's fine; it
  would need a conditional/stub import if the project ever also built
  for Android/iOS.
- The Leads list has search but no filter row yet (by status/source/
  overdue). Reports already breaks leads down by status and source if
  you need that view today; a quick filter chip row on the list itself
  would be a natural next step.
- The leaderboard and reports screens fetch and aggregate client-side,
  which is fine at small-to-medium team size. If the team grows large,
  move the aggregation into a Postgres view/RPC for speed.
- The leaderboard currently ranks everyone together; it doesn't split
  Sales vs Telecaller into separate boards yet.
- Purpose/Budget aren't shown in the compact lead row or the "Recent
  leads" list (kept those minimal on purpose for scanability) — they
  are visible on the lead detail screen and in CSV export.
