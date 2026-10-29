# Changelog

All notable changes to this project are logged here — **one entry per completed
task, appended after the work is done and before the commit is made.** The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/) once there
is a numbered release to version. Until then, everything lands under
`[Unreleased]`.

Workflow rules this changelog lives by:

- A task is logged here **before** its commit — if the code changed and there
  is no entry, the change is not ready to commit.
- All changes reach GitHub as **clean PRs** (branch → CI green → review →
  merge to `master`). Nothing is pushed to `master` directly.
- Entries describe user- or repo-visible impact, not implementation trivia.
- History predating this file (2026-09-05) is preserved in `git log` and
  `TASKS.md` — this log starts at the current collaboration.

## [Unreleased]
### Added — 2026-10-27 — buyer Stitch flow

- Added governorate and area selection, an authenticated notification inbox, account/profile editing and tomorrow-postponement confirmation directly in the existing Flutter project. Reused the established cream/brown theme, RTL typography and existing layers; added buyer Home/My booking/Account navigation and owner account/inbox actions.
- Kept geography based on actual stores, provided explicit loading/error/retry states, isolated session data on logout/user changes, and protected profile saves from duplicate submissions and late replies. Postponed bookings retain their identity/payment, consume tomorrow's quota/capacity, remain visible ahead of collected-today receipts, and invalidate the old-date QR.
- Added four ordered Supabase migrations and scoped SQL tests. **Migrations are not deployed and SQL tests were not executed here**; live inbox, profile saving and postponement require the server deployment described in `docs/superpowers/plans/2026-10-27-server-deployment.md`. No production booking/profile/database writes were made for preview.
- Verified the full Flutter suite: 269 pass, 2 existing skips; `dart analyze --fatal-infos` reports no issues. Release assembly passed with the established Android lint exclusions; updated the existing Pixel_8 with the same package/signature and preserved app data. Visually checked the live owner account screen. Original Android Studio is open on `governorate_screen.dart`; simultaneous IDE/emulator operation is constrained by the 6 GB host.
- Five production-widget fixture previews are available in `../analysis/buyer-flow-five-screens.zip`; actual device account screenshot is `../analysis/new-flow-runtime-account.png`. Fixture previews use controlled test data and are labelled separately from device screenshots.

### Changed — 2026-10-27 — remaining Stitch screens

- Restyled the remaining 12 functional interfaces directly in the existing 10 Dart files: ID/selfie capture, verification waiting/result, purchase review, payment number/OTP/success, owner queue, QR scanner, customers, history and day details. Reused the cream palette, IBM Plex Arabic, white rounded cards, loaf/bread assets and pill actions; kept routes, controllers and service callbacks.
- Made camera/error/result screens, forms, metadata and owner actions scroll at narrow widths, large text and landscape. Kept camera-only capture and real scanner/redemption guards. Payment and verification remain the existing simulations; no new integration or real reservation was created for preview.
- Verified 161 selected visual/queue/payment/verification/a11y tests pass (2 pre-existing skips), with `dart analyze --fatal-infos` reporting no issues. Android release assembly passed after preserving/rebuilding a damaged Gradle transform cache; Android lint tasks were excluded by the existing environment workaround, and D8 Kotlin metadata warnings remain.
- Verified unchanged package/signing certificate, updated the existing Pixel_8 with `install -r --abi x86_64`, and visually checked the live owner queue. Original Android Studio project is open on `owner_queue_screen.dart`. Preserved existing Studio settings and used a fresh IDE system cache to avoid a stale socket lock. Device retains the established software-renderer launch flags.
- Review artifacts: `../analysis/remaining-runtime-owner-final.png` is a real AVD screenshot; `../analysis/raghif-remaining-screens.zip` contains production-widget test fixtures (including scanner camera-unavailable state), not device screenshots. Existing legacy “undo pickup” label still invokes the idempotent collect API; no reversal backend was introduced.

### Changed (Stitch application screens)

- Restyle the existing onboarding, registration, shared login, bakery list,
  bakery details, QR receipt, current order and owner dashboard with the
  cream Stitch palette, IBM Plex Arabic, loaf identity and rounded cards.
- Retain the existing authentication fields, search and availability guards,
  live order data, QR payload, receipt export and owner settings actions.
- Check production screens at phone, narrow/large-text and landscape sizes;
  verify focused behavior and accessibility checks, build the existing Android
  package and update it on the existing Pixel_8 without clearing application data.

### Changed (Stitch launch identity)

- Match the first Stitch splash design in the existing Flutter entrypoint:
  cream background, warm bread emblem, Arabic IBM Plex typography, wheat
  decoration, progress dots, and a pressed-state start button.
- Open the existing onboarding or authentication flow from the start button,
  and use matching cream/vector Android launch resources in light and dark mode.

### Changed (local Android setup)

- Use the Gradle 8.12 binary distribution instead of the full distribution.
  This keeps the build-tool version unchanged and avoids downloading its
  sources and documentation when setting up Android Studio.
- Limit Gradle memory and workers for the local emulator setup, and allow
  the existing Arabic Windows checkout path without moving the project.

### Changed (data source)

- **The server is the only source of data.** The on-device `drift` database
  is gone. Every screen now reads Supabase directly and updates live through
  Realtime. The signed-in user is the Supabase session, and the profile
  behind it is read from the server every time. Nothing about other users is
  stored on the phone.
- **One exception: the buyer's latest receipt is kept on the phone**, so the
  pickup QR still opens with no signal at the bakery. It is written only from
  a server answer, and cleared on sign-out or when the server says the order
  is gone.
- **Notifications come from the server only.** "Purchase confirmed" is now a
  push sent by `notify-batch` (new trigger on purchase insert, migration
  `20261003172252_notify_purchase_confirmed`). The phone no longer raises its
  own "purchase confirmed", "batch released" or OTP notifications. The mock
  login and payment codes are shown on screen, as before.
- `constitution.md` §I–II, `spec.md` and `README.md` record the change
  (ruling dated 2026-10-03).

### Fixed (sign-out)

- **Signing out from any screen lands on the login screen, with nothing
  behind it.** Signing out from the store list (a pushed screen) used to
  leave the store list on screen, with the login form hidden underneath it
  and reachable by pressing back. Crossing between signed in and signed out
  now clears every pushed screen, wherever it happens.
- **Signing out empties the on-device cache.** It held whatever the last
  account could see; for an owner, that included every buyer's name and
  national ID. The next account on the phone starts from its own data.

### Fixed (purchase cache)

- **Purchases deleted on the server now disappear from the phone.** The
  sync only ever added or replaced cached purchases, so a purchase removed
  server-side kept showing as "already bought today" until the app's data
  was cleared. Each pull now drops cached purchases the server no longer
  returns.

### Added (demo accounts)

- **Second demo buyer, حسن الخليلي** (`900444555`, PIN `1234`), in the login
  screen's demo sheet and the `seed-demo` account list, so two phones can
  test the queue at once (each account gets one bag a day).

### Fixed (release signing and config)

- **Release builds no longer ship with a throwaway debug key.** The release
  workflow used to fall back to the runner's debug key when the keystore
  secrets were missing; that key changes every run, so phones could not
  update over an earlier install. It now fails instead, and the signature
  check rejects any APK signed with the debug key.
- **Local release builds use the real keystore.** `storeFile` in
  `android/key.properties` is now resolved from `android/app/` (Flutter's
  documented layout), where the keystore actually lives. Before, the path
  never matched and local builds were silently debug-signed.
- **Supabase URL and anon key can be repo Variables.** The release workflow
  reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from repo variables first, then
  secrets. Both ship inside the APK, so they are not secret.

### Removed (CI)

- **Pixel golden tests are gone.** They failed on tiny rendering differences
  between machines (e.g. a 0.11% diff on the store list) and blocked PRs over
  UI changes, not broken behaviour. The widget and logic tests stay in CI.
  `test/goldens/test_fonts.dart` is kept because other tests use it.

### Fixed (release build)

- **The release APK now ships the real backend config and a real signature.**
  It was built from the dummy `.env.example` (so the app could not reach
  Supabase) and signed with the debug key. `release.yml` now writes `.env`
  from the `SUPABASE_URL` / `SUPABASE_ANON_KEY` secrets (failing if unset),
  signs with the `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` /
  `KEY_PASSWORD` secrets, and verifies the signature with `apksigner`.
  Installs signed with the old debug key must be uninstalled once first.

### Fixed (login errors)

- **A bad connection no longer reads as a wrong PIN or "not registered".**
  Every sign-in call swallowed all errors into `null`, so a phone with no
  signal was told its ID had no account and offered "create an account". The
  gateway's own 401/404 answers still mean "wrong PIN/code" and "unknown ID";
  anything else (no connection, a timeout, a 5xx) now surfaces as "could not
  reach the server, check your connection and try again", with the PIN field
  still there to retry.

### Added

- `constitution.md`: the project's non-negotiable rules, linked from the
  README. Its CI rule (VII) reflects the 2026-09-30 amendment: PRs run analyze
  + test, the APK is built once per merge.
- `.gitignore` covers the Supabase CLI's local link state and the local
  briefing documents folder.

### Changed (i18n)

- One string for "paid": `paidLabel` and `paidBadge` both held `مدفوع` and
  rendered the same chip, so a wording edit could leave one stale. `paidBadge`
  stays; buyer home uses it.

### Changed (CI)

- **PRs run analyze + test only; the APK is built once per merge.** The single
  `build` job used to analyze, test, build a release APK and upload it on every
  PR update and every master push, so each PR built an app nobody looked at and
  every merge repeated the PR's work. Now `ci.yml` (PRs) is `flutter analyze` +
  `flutter test` and `release.yml` (merge to master, or on demand) builds the
  arm64 APK and replaces the rolling `latest` release directly, with no
  artifact upload/download hop. Setup shared through
  `.github/actions/flutter`, Gradle caching through `setup-java`, and the
  Flutter pin moved to `environment.flutter` in `pubspec.yaml` so local,
  CI and release cannot disagree. The 180s shell timeout on the tests is gone
  (the job's 10-minute limit covers a hang; the suite takes ~2 minutes).
  Constitution VII amended accordingly (untracked file, 2026-09-30).

### Deployed

- 2026-09-30, project `mgmerkaokkffsypnkryj`: migration
  `lock_direct_writes` applied (recorded as `20260930130626`) and
  `auth-gateway` v14 deployed (seed-demo gated, OTP checked server-side).
  Verified against the live project: anonymous callers are refused on the
  owner RPCs, `select *` on `profiles` is refused for signed-in users while
  named columns work, the demo owner signs in, and the owner aggregates
  return. `SEED_DEMO_SECRET` is not set, so `seed-demo` is disabled; the
  database already holds the demo world.

### Fixed (sign-out)

- **Sign-out works when the server cannot be reached.** `logout()` awaited
  `signOut()`, which revokes the session on the server, so with the backend
  down it threw, the bloc never emitted `Unauthenticated`, and confirming
  the sign-out dialog did nothing. The revoke is best effort now and the
  remembered user is always cleared.

### Changed (login)

- **Login is one question per screen.** National ID, then PIN, then in.
  The first screen used to carry about nine competing things (a demo badge,
  logo, title and subtitle, a card, two alternative-login links, a create-
  account row and a demo-accounts card); it is now a field, a button and two
  quiet links. The PIN is the normal way in and the code by "SMS" is behind
  "forgot your PIN?" — previously the code was the default and the PIN a
  link on a screen you only reached after asking for a code. The fourth PIN
  digit signs you in. Demo accounts moved into a bottom sheet and sign in on
  one tap. An ID with no account is told so with "create an account" right
  beside it. System back goes back a step.
- **Fixed: a new phone could not use the code login at all.** Asking for a
  code first checked this device's cache for the user, so anyone with an
  existing account on a fresh install was told to create one. The server
  decides now.

### Fixed

- **Direct table writes are closed.** `purchases` and `scan_events` no longer
  accept inserts/updates from the app, so `reserve_bag` (sold-out, batch
  number, one bag a day) cannot be bypassed. `profiles.pin_hash` and `role`
  are no longer readable or writable by the app — the owner's device used to
  pull every buyer's bcrypt hash with `select *`; the sync now names its
  columns. Migration `20260930130626_lock_direct_writes`.
- **RPC rules moved into SQL.** `collect_purchase` refuses a batch that has
  not been called; `record_scan` only takes known outcomes and never links a
  purchase from another store; `save_store_allocation` locks the store row
  (no oversell race) and no longer takes `is_open` from the client's cache.
  The new RPCs are revoked from `anon`.
- **Failed writes are no longer silent.** Owner actions, the scanner and pin
  toggles report "did not happen" via `guardWrite` instead of leaving the
  scanner stuck; server errors reach the UI as `BackendUnavailableException`
  rather than raw driver errors, and only the exact sold-out message maps to
  `StoreSoldOutException`.
- **`auth-gateway`:** `seed-demo` is disabled unless the
  `SEED_DEMO_SECRET` function secret is set and sent as `x-seed-secret`;
  `otp-confirm` now checks the (mock) code server-side instead of minting a
  session from a national ID alone (`loginWithOtp` takes the entered code).
- Cache reads no longer invent facts (`batch_number ?? 1`, `createdAt = now`),
  and an upgrade from an install that stored the session id as an int no
  longer fails sign-in.
- SQL tests: `flutter/supabase/tests/run.sh` applies every migration to a
  throwaway Postgres (docker) and asserts the above as real roles.
- **Accessibility floor (constitution V), measured in `test/a11y`.** Body
  text is 16sp (was 15); field labels sit above the field at full size (the
  floating label shrank to ~12.75sp once you typed); input outlines are
  4.8:1 instead of 1.5:1; chip text on status tints is ~8:1; the demo rows
  are 48dp with 8dp between them; Arabic styles no longer set `letterSpacing`
  (it disables ligatures); the demo badge pads with `EdgeInsetsDirectional`.
  Registration lost its box-in-box field cards; the owner's pending-pickup
  count is a numeral, not a pill.
- **Fewer expensive accidents.** Signing out and closing the bakery ask
  first; the daily-bag stepper moves by 10.
- **Boot no longer waits on the network.** The first store pull is not
  awaited, so an unreachable backend shows the app instead of a permanent
  splash screen.

### Changed

- **Postgres is the source of truth; drift is a cache.** The app used to
  seed its own stores, buyers and queue on every install and decide the
  rules on-device, with Supabase wired in behind a `USE_SUPABASE` flag as
  a second opinion. That split is what let a receipt read "batch 4" while
  the server had the same row as batch 1. Now:
  - Every write is a Postgres RPC that authorizes itself
    (`reserve_bag`, `notify_next_batch`, `collect_purchase`,
    `set_store_open`, `record_scan`, `set_store_pinned`,
    `save_store_allocation`). The owner's customer book and sales history
    are computed in SQL.
  - The demo world is seeded server-side and idempotently by
    `seed_demo_buyers` / `seed_demo_stores` / `seed_demo_day`, driven by
    the `seed-demo` Edge Function action. `DemoContentSeeder` and the
    local `ensureSeeded()` calls are gone.
  - Ids are Supabase UUIDs everywhere — device, server and QR code. The
    local `INTEGER AUTOINCREMENT` ids and the `remote_id` mapping columns
    are gone, along with the `dynamic` id parameters and `_parseInt`
    coercion they forced on the controller.
  - **Writes require the backend** and fail loudly
    (`BackendUnavailableException`) instead of being applied locally and
    reconciled later. Reads still serve from cache while offline.
  - Drift schema v8 drops and recreates every table. There is no
    column-by-column upgrade from v7: the old ids named rows that only
    existed on one device, and a cache is cheap to refill.
  - QR payload is v2. **v1 receipts no longer scan** — they carry integer
    ids that identify nothing now, so they are rejected rather than
    resolved to whatever row shares the number.
  - Pickup is one-way: the old notified↔collected toggle is now
    `collectPurchase`. Bread that has been handed over cannot be
    un-handed, and the server offers no way back.
  - Removed as dead: the `dio`/`retrofit` scaffold that never had a server
    to talk to, the `useSupabase` flag, `pin_hash` from the local cache
    (PIN checks are the auth-gateway's job), and `AuthRepositoryImpl`.

### Fixed

- Push notifications — four defects found by tracing the live pipeline
  (trigger → pg_net → `notify-batch` → FCM) end to end:
  - **Duplicate batch alerts.** The Edge Function selected every purchase
    still sitting at `notified` for the store/day, so releasing batch 2
    re-alerted every uncollected buyer in batch 1, and batch 3 re-alerted
    batches 1 and 2. The trigger now sends `batchNumber` and the function
    filters on it. The trigger also joins the OLD transition table so it
    fires only for rows that actually crossed into `notified`, instead of
    any statement that happens to leave a row there.
  - **`notify-batch` was an open push relay.** `verify_jwt` is off (pg_net
    carries no session) and nothing else authenticated the caller, while
    store ids are world-readable — so anyone could alert every waiting
    buyer in any store. The trigger now sends a shared secret from Vault
    (generated by the migration, never committed) which the function
    verifies, failing closed when unset.
  - **Logout left the device subscribed.** `logout()` signed out without
    removing the row from `device_tokens`, so the handset kept receiving
    the previous user's batch pushes — the `auth.uid() = user_id` RLS
    policy means the delete has to happen *before* `signOut()`. Covered by
    a test that asserts the ordering.
  - **Backgrounded pushes used the wrong channel.** The Arabic
    `queue_notifications` channel was only applied to foreground messages,
    so OS-rendered pushes — the ones that matter — landed in Android's
    auto-created "Miscellaneous" channel at default importance. The channel
    is now created eagerly at startup, declared in AndroidManifest.xml as
    `default_notification_channel_id`, and named in the FCM payload.

  Requires a one-time `supabase secrets set NOTIFY_BATCH_SECRET=...` to the
  Vault value; until it is set the function rejects every call.

### Added

- CHANGELOG.md — task log for the current collaboration (this file).
- PR-only GitHub workflow convention: work happens on a branch, CI
  (`flutter analyze` + `flutter test` + release APK) must pass, and merges
  to `master` happen only via reviewed pull requests.
- Owner pickup flow (#28 + audit items): QR redemption scanner on the buyer
  queue screen — new `qr_scanner_screen.dart` (mobile_scanner dependency +
  CAMERA permission) and camera-free decode/match logic in
  `qr_redemption.dart` with unit tests.
- docs/AUDIT-2026-09-05.md — code review report against `master` with a
  per-screen findings matrix and a prioritized P0–P2 task inventory.
- docs/PROTOTYPE-WALKTHROUGH.md — presentation script for the prototype
  demo (buyer + owner story), with each beat tagged READY / PARTIAL /
  BUILD / PRODUCTION, a build-order roadmap, and presenter guardrails.

### Changed

- Identity verification photos (ID photo + selfie) are now captured live with
  the camera — the selfie from the front camera, the ID from the rear. The
  gallery/picker path is deliberately gone: an uploaded image could be a photo
  of a photo or of someone else, which would defeat the identity check. A
  camera failure (permission denied, no camera app) now shows an Arabic error
  instead of a silent no-op.
- Receipt QR payload is now versioned (`v: 1`) and carries `national_id` +
  `store_id` (both optional, so codes minted before the change still decode).
  The scanner can now report a wrong-store code from the code's own store
  claim — no local purchase needed — and shows the buyer's national ID on
  the scan result card. A `qr_payload.dart` header comment (Farid's) records
  the production roadmap: opaque signed server-issued token, no PII in the
  code, server-side redemption.
- Receipt QRs (on-screen, saved, shared) now render at error-correction
  level H (~30% recovery) instead of the default L — codes survive glare,
  blur, and screen reflections from photographed/phone-screen receipts.
- QR redemption scanner gains a torch (flashlight) toggle overlaid on the
  camera preview for low-light pickup counters — hidden automatically on
  devices without a torch; torch switches off when the camera stops.
- Owner queue buyer rows now show national ID + phone so pickup identity can
  be verified, with a live search field matching ID/phone suffix or name;
  the Notify-Next-Batch action is hidden during a search so a lookup can
  never release a batch accidentally.
- `PurchaseModel` and all repository row mappings now carry the buyer's
  national ID (users table join).

### Fixed

- The "log in with your PIN instead" link on the sign-in screen no longer
  shows before a National ID is typed — PIN login is an alternate path for an
  identified user, so offering it on an empty form only added a dead end.
  Login golden regenerated.
- Buyer queue status chips ("تم الاستلام", "تم الإشعار") broke across two
  lines on a phone-width card, splitting the word mid-letter. The chip now
  keeps its intrinsic width and the pickup time wraps below it instead.
- Demo content is now seeded once per calendar day instead of once per
  install. Every queue read filters on today's date, so a build installed on
  one day showed an empty owner queue, dashboard and history the next — the
  seeder bailed out as soon as any purchase existed. Earlier days are kept,
  so the history screen gains real past days to browse, and the demo store's
  bags are restocked to its daily allocation each day.
- A closed bakery on the store list read "نفدت الكمية" (sold out), blaming
  the owner for stock they never put out. Closed stores now show "مغلق" on a
  neutral chip; sold-out keeps the red chip. Store list golden regenerated.
- Android launcher label was the latin placeholder "raghif"; it is now رغيف,
  matching the app's Arabic-only UI.
- Store list golden (`store_list_screen.png`) regenerated — it was stale
  against the current store card layout, failing CI (0.02%, 58px diff) on
  every branch regardless of its own changes.
- CI: the store list pixel golden flipped between green and red on
  byte-identical trees (0.002–0.005% of pixels: different CI runners
  rasterise fonts slightly differently), so master and every open PR showed a
  red build that had nothing to do with the branch. The golden is kept — the
  comparison now tolerates ≤ 0.1% of pixels and still fails on any real
  layout change (verified: a full-screen overlay still fails at 100%).
- Owner allocation save no longer resets today's remaining bags to the full
  daily limit, wiping out bags already sold before the save.
- Buying a bag after a store sells out is now rejected instead of silently
  clamping remaining stock to zero and completing the purchase anyway.
- Logging back in after registration/onboarding no longer leaves the stale
  login screen on top of the app.
- Registering with a phone number or national ID already on file now shows
  an Arabic message instead of a raw database exception.
- Registration form: the Jawwal Pay number now correctly defaults to the
  phone number typed above it. The old listener compared the updated phone
  against the wallet field's previous value, so it copied only the first
  keystroke and never tracked later edits. It now mirrors the phone until
  the user types their own wallet number (their value then wins; clearing
  the field restores the phone default).
- Flutter web build no longer fails to compile: `QueueController`'s no-DI
  fallback unconditionally imported `drift/native.dart` (`dart:ffi`), which
  isn't available on web, even though that fallback never runs once
  `main()` sets up DI. The native import is now conditional so web builds
  compile and behavior is unchanged elsewhere.
- PurchaseScreen no longer centers its content in the middle of the screen
  (leaving large dead space above and below on short content) — the store
  detail block now sits directly under the app bar and the buy/back buttons
  are anchored to the bottom.
- PurchaseScreen no longer shows the price twice — removed the separate
  price row since the buy button already states the amount.
- `OwnerDashboardScreen`'s allocation/batch-size fields could silently sync
  from stale placeholder data (`QueueController`'s hardcoded `defaultStores`)
  instead of the real repository values, because the widget couldn't tell
  the two apart once loaded. Added an explicit `storesLoaded` signal to
  `QueueController` so the one-time sync waits for real data.

### Added

- Pickup scans now play a tone and a haptic: a two-note "ding" when a bag is
  handed over, a low buzz for every other outcome (already collected, batch not
  called, wrong store, not found on this device, unreadable code) — so the owner
  can hear the result mid-queue without reading the screen. Tones ship as
  `assets/sounds/scan_success.wav` / `scan_failure.wav` via `audioplayers`,
  pinned below 6.8.0 because that release needs Flutter >=3.44 while CI builds
  on the pinned 3.41.6.
- Scan audit trail: new `scan_events` table (schema v5) records every attempt —
  store, matched purchase when there is one, outcome, scanned name/national ID
  and timestamp. This is the owner's "scan writes every detail to DB", and the
  raw material for the day/history view.
- **Store details screen** — tapping a store now opens a hub before buying:
  identity (name, area, availability, pin toggle), today's stock + purchase
  window, "طلبي اليوم" (order state, paid badge, and "اعرض وصل الاستلام" to
  reopen the receipt QR), the last visit, and the buy CTA. Cards stay tappable
  when a store is sold out or closed, since the screen is where that's
  explained.
- Buyer store list: **search** (store name or area), **area filter chips**,
  and **pin-to-top** — a pinned store always sorts first. Stores the buyer
  actually uses (an order today, or any past purchase) float up on their own
  and get a richer card: order state (بانتظار دورك / جاهز للاستلام /
  تم الاستلام), a paid badge, and the last purchase date (اليوم / أمس /
  date). Ordering/filtering lives in `store_list_logic.dart` (pure, unit
  tested). Schema v4 adds a per-buyer `store_pins` table and a
  `stores.area` column, both with migrations.
- Richer demo content for the walkthrough (P0-1) — new
  `lib/data/demo_content_seeder.dart` runs once after the base seed on fresh
  installs: 7 stores total (4 extra bakeries), 9 dummy registered buyers,
  and today's demo-store queue spanning all pickup states (3 collected /
  3 notified / 3 waiting across three visible batches). Kept separate from
  `ensureSeeded()` so existing tests see the old minimal footprint; the live
  demo buyer أحمد gets no seeded purchase (one-bag rule). Unit tests cover
  the seed, its idempotency, and the no-op-on-used-install guard.
- Buyer home — "طلبي" (walkthrough P0 #2): the buyer now lands on their current
  order instead of the store list: live status (waiting → ready → collected,
  updating by itself), the paid badge, the batch number, and
  "اعرض وصل الاستلام" which reopens the pickup QR at any time. Until now the
  receipt only existed on the confirmation screen — leave it without saving and
  the ticket was gone. No ETA is shown: a time-to-next-batch needs a real
  owner-set batch schedule (decision C), so the screen stays honest with batch
  + status.
- Owner queue & dashboard polish (walkthrough P1 #6/#7):
  - every batch header now shows its tallies — تم الاستلام / بانتظار الاستلام /
    لم يُنادَ — so the owner sees who never showed up without counting rows.
  - "إشعار الدفعة التالية" asks for confirmation first, and the dialog warns how
    many buyers from earlier batches were called but never picked up (soft
    release-after-collected discipline: a hard block would deadlock the owner
    when someone simply never shows up).
  - the dashboard shows the live "بانتظار الاستلام" count (paid, not picked) and
    an in-app low-stock warning at ≤ 20 bags.

### Fixed

- Owner queue buyer rows overflowed (yellow/black stripes) once a row reached
  تم الإشعار / تم الاستلام: the confirm button took the width from the buyer
  info column, which then couldn't fit the status chip and time.
- Owner history page (walkthrough P0 #4): a day browser over the same queue the
  owner already works with. One grouped query per store gives each day's totals
  — sold, collected, and the end-of-day leftover (paid, never picked up) —
  newest day first; tapping a day lists its buyers with their status. Reached
  from a new "سجل المبيعات" button on the owner dashboard.
- Store owners can now set today's purchase window (start/end time), shown
  to buyers on the store list and purchase screen alongside the existing
  bags-remaining count.
- Notifying the next batch now fires a real OS notification, simulating the
  push notification a buyer would get in production — there's no backend
  in this prototype, so it fires directly on whatever device runs the
  owner's "Notify Next Batch" action. Uses `flutter_local_notifications`
  (previously an unused dependency); no-op on web.

### Changed

- TASKS.md backlog synced with reality: #7 (real drift queries) and #8
  (widget tests) marked done — both closed COMPLETED on 2026-09-05; #28
  (store-owner QR redemption scanner) added as the only open item. Two
  collaboration rulings recorded there: app is Arabic-only for now (no
  EN/bilingual work), and the bag limit is one per national ID per day
  across all stores.
- TASKS.md collaboration rules hardened (agreed 2026-09-06): all work lands
  on feature branches only; `master` is never pushed to or merged to locally
  — it changes only via reviewed PRs; when `master` gains new code it is
  merged/rebased into working branches, never extended directly.

