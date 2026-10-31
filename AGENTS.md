# Agent notes — Raghif

Read this before changing anything. It records how the backend is wired, which
invariants the queue depends on, and what is deliberately still open. The
README covers running the app; `constitution.md`, `spec.md` and `UI_SPEC.md`
cover product intent.

## Layout

- `flutter/` — the app. Screens in `lib/features/<feature>`, Supabase access in
  `lib/data/repositories`, tokens in `lib/core/theme`, DI in `lib/core/di`.
- `flutter/supabase/migrations/` — the only source of truth for schema.
- `flutter/supabase/tests/` — rollback-only SQL suites (`bash tests/run.sh`).
- `docs/superpowers/` — redesign plans and specs.

## The database is the only data source

- Every screen reads Supabase. There is no on-device database and no
  `USE_SUPABASE` switch; do not reintroduce a local database or cache as truth.
- Schema changes go in a new migration under `flutter/supabase/migrations/`.
  Never change live objects without a matching file.
- If you apply a migration out of band (MCP / SQL editor), also insert its repo
  version into `supabase_migrations.schema_migrations`, or `supabase db push`
  will try to re-apply it and fail. Current versions:
  `20261027140000` store_governorates, `20261027141000` notification_inbox,
  `20261027142000` update_my_profile, `20261027143000` postpone_purchase,
  `20261029120000` harden_table_privileges.
- The hosted Supabase MCP server is scoped to project `mgmerkaokkffsypnkryj` by
  its URL. Do not pass a `project_id` argument; the tool schema has no such
  field.

## RLS and grants

- Every table in `public`: RLS enabled, then explicit
  `revoke ... from anon, authenticated` followed by the minimum grant.
  Supabase's default privileges are wider than this app needs.
- `anon` may read `stores` and nothing else. It has no write privilege on any
  table; keep it that way.
- `profiles` uses column-level grants. `role` and `pin_hash` must never be
  readable by the client.
- `security definer` functions must check `auth.uid()` and scope every write by
  the caller. Newer functions use `set search_path = ''`; the queue RPCs still
  use `public` — convert them to `''` when you touch them.
- Never grant `TRUNCATE`, `REFERENCES` or `TRIGGER` to `anon`/`authenticated`.
  TRUNCATE ignores RLS.

## Queue invariants — do not regress

- "Today" is the server date in `Asia/Hebron`. Every queue RPC rejects any other
  date, including `reserve_bag` and `save_store_allocation`.
- Lock order is always **stores row first, then purchase row**. Keep it in every
  RPC, or the queue deadlocks under load.
- `stores.daily_bag_limit` is standing capacity, not a per-date quota.
  `stores.bags_remaining` is today's stock and is recomputed by
  `save_store_allocation`.
- `unique (user_id, purchase_date)` means one booking per person per day across
  all bakeries. Postponement keeps the same row and identity; it never inserts
  a second reservation or payment.
- Postponement: today only, `waiting`/`notified` only, once
  (`postponement_count` is `0..1`), consumes tomorrow's quota and capacity,
  resets the booking to `waiting`, returns the bag to today's `bags_remaining`,
  and makes the old-date QR stale (`receipt.purchase_date` no longer matches).
- `notification_inbox` rows are written only by the `purchase_inbox_event`
  trigger. Clients may read their own rows and mark them read through the two
  RPCs; they have no insert/update/delete privilege.
- `record_scan` accepts a closed list of outcomes. Adding an outcome means
  changing the function and the Dart enum together.

## Known open issues — decide explicitly, do not drift into them

- `update_my_profile` can change `phone`, which is the login identifier, with no
  proof of ownership and no re-authentication. A stolen session becomes a
  persistent takeover. Either require the current PIN / an OTP to the new number,
  or make phone a support-only field.
- The same RPC returns `phone already registered`, which lets any signed-in user
  probe whether a number has an account. Return a generic error or rate-limit.
- `authenticated` still holds `UPDATE (verification_status)` on `profiles` so the
  simulated Jawwal Pay step can flip it. That means the account screen's
  "ID/role/status read-only" promise is not enforced by the API. Moving the flip
  into an RPC and revoking the column grant is the fix.
- Postponement writes an inbox row but sends no push: push triggers fire on
  insert and on `status = 'notified'` only.
- `purchases.original_purchase_date` is written and never read. Surface it in
  receipts/history or drop it.
- Nothing sets `stores.governorate` for future stores, and there is no owner UI
  for it. New bakeries will be invisible in the governorate screen until
  classified.
- Notification title/body copy is hardcoded Arabic inside the trigger, with ISO
  dates. Changing it needs a migration.
- The inbox fetch is unbounded; add a limit/pagination before it grows.

## Unmerged backend hardening

Remote branch `chore/backend-hardening-and-spec-rewrite` holds three commits that
are **not** in `master`: bounded/retry-proof `reserve_bag`, RPC-only writes to
`stores`, a 5-miss/15-min PIN lockout with a 4-digit PIN check, a spec rewrite
(`ARCHITECTURE.md`, `TASKS.md`, `docs/BACKEND-REVIEW-2026-10.md`), and removal of
dead dependencies. It predates the Stitch redesign and conflicts heavily.

Do not merge it blindly and do not re-implement its ideas from scratch without
reading it. Re-apply the hardening onto the current queue RPCs (the
redesign replaced `reserve_bag`, `save_store_allocation`, `notify_next_batch`,
`collect_purchase` and `record_scan`), keeping the date/lock/capacity invariants
above.

## CI and builds

- `ci.yml` runs on pull requests: `flutter analyze` + `flutter test`.
- `release.yml` runs on a push to `master`: builds the release APK with the real
  Supabase project and replaces the rolling `latest` release.
- `apk.yml` builds both a debug and a release APK and uploads them as one
  artifact; it never touches `latest`.
- `SUPABASE_URL` / `SUPABASE_ANON_KEY` live in repo variables (they ship inside
  the APK, so they are not secrets). The workflows overwrite the dummy `.env`
  from `.env.example`; a build without them fails on purpose.
- Release signing needs `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD`. Never let a release build fall back to the debug key.
- Runners raise the Gradle heap to 4 GB: the checked-in 1536 MB is tuned for a
  6 GB laptop and OOMs Jetifier on the Flutter engine jar.
- APKs are `android-arm64` only, so they install on phones but not on x86_64
  emulators.
- There are no golden tests. `test/visual/*` only writes PNGs when
  `STITCH_SCREENSHOT_DIR` is set; it never compares pixels.

## House rules

- Add a `CHANGELOG.md` entry before committing a change.
- Work on a branch, open a PR, let CI go green, then merge to `master`.
- Never commit `.env`, keystores, tokens or service keys.
