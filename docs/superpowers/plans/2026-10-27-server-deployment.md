# Buyer flow: server deployment handoff

The Flutter implementation is in the original checkout. These server changes are **not deployed** and SQL tests have **not run** in this environment (no Docker/Postgres runtime). Existing app authentication configuration does not grant database administration.

## Ordered migrations

Apply to the existing project's staging database first, using its normal Supabase migration workflow:

1. `flutter/supabase/migrations/20261027140000_store_governorates.sql`
2. `flutter/supabase/migrations/20261027141000_notification_inbox.sql`
3. `flutter/supabase/migrations/20261027142000_update_my_profile.sql`
4. `flutter/supabase/migrations/20261027143000_postpone_purchase.sql`

They extend the existing schema; they do not create another app or project. The ordered SQL handoff artifact is `../../../../analysis/buyer-flow-server-migrations.sql` relative to this document. Review and back up the existing database before production deployment. Record the applied migration versions using the project's established workflow; do not reapply migrations already recorded as applied.

## Verification

- On a disposable database with Docker, run `bash flutter/supabase/tests/run.sh`. This runner creates/removes its own disposable container. Never execute its fixture SQL on a production database.
- In staging, verify each user can see/read only their own notifications; signed-out and cross-user calls fail. New reservation, ready and postponement events create inbox entries transactionally; historical events are not backfilled. This adds an in-app inbox, not push delivery.
- Verify a profile update preserves identity, role, verification status and PIN. Blank optional wallet clears it; invalid phone/name are rejected.
- Verify one same-bakery postponement from today's uncollected booking consumes tomorrow's quota/capacity without a second payment. Collected, past, duplicate tomorrow, second postponement, full-capacity and other-user requests fail. Old-date QR is rejected; tomorrow cannot be notified/collected today. Use the server's Asia/Hebron date.
- Verify existing reserve/notify/collect and owner allocation flows after the updated RPCs. Governorate metadata is nullable; unmapped stores remain accessible through browse-all and require actual administrative classification.

Until deployment, the app must show unavailable/retry for missing inbox/profile/postponement RPCs instead of reporting success. Local widget/repository tests use controlled fixtures and do not prove remote SQL execution.
