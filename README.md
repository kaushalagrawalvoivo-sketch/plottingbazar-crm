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

Two roles: `admin` and the default sales role (managed in **Manage
Users**, admin-only screen).

| Data          | Admin sees        | Sales employee sees                          |
|---------------|--------------------|-----------------------------------------------|
| Leads         | All                | Only leads assigned to them                    |
| Customers     | All                | Only customers assigned to them                |
| Bookings      | All                | Only bookings for their own customers          |
| Plots / Sites | All (full CRUD)   | Read-only, all (needed to create bookings)     |
| Call logs     | All                | Only for their own assigned leads              |
| Feedback      | All                | Only for their own assigned leads              |
| Activity feed | Full live feed    | Not shown (admin-only screen)                  |

This is enforced with Postgres Row Level Security (RLS) policies, so
even a modified/compromised client can't bypass it — the restriction
lives in the database, not just the app's UI.

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
                      admin monitoring feed
supabase/
  20260713_lead_assignment.sql   (existing)
  20260808_crm_upgrade.sql       (new — see section 3)
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

## 8. Known limitations / good next steps

- Bulk-assign for customers (like the existing bulk-assign on the
  Leads screen) isn't built yet — customers are assigned one at a time
  via Edit Customer. Worth adding if the customer list grows large.
- Local follow-up notifications are per-device; if an employee doesn't
  open the app on a given day, they won't see that day's reminder until
  they do. A server-side push (still free via Supabase Edge Functions +
  Web Push) would make this fully reliable, but wasn't in scope here.
- No automated tests were added for the new tables/services.
