# Buyer Stitch Flow Implementation Plan

> **For agentic workers:** Use subagent-driven-development for disjoint feature groups, followed by central serial verification/review. User explicitly requires the existing checkout directly; do not create a worktree or commit/push.

**Goal:** Add five working, organized Stitch screens and their navigation to the same original app.
**Architecture:** Existing Dart layers/DI/Bloc/controllers. Geography derives from StoreModel; notifications have a dedicated repository; account extends AuthRepository/Bloc; postponement extends the authoritative queue repository and transactional SQL. Root integrates navigation after disjoint edits finish.
**Tech Stack:** Flutter3.41.6/Dart3.11.4, existing Supabase/Material/widgets, no new dependencies.
**Spec:** ../specs/2026-10-27-buyer-stitch-flow-design.md

## Global constraints

Same project/files/language and preserved previous edits; additive new feature files only. Existing cream theme/RTL/IBM font; real data or honest empty/error, no placeholder actions. >=48dp labelled actions, >=15sp text, keyboard/320dp/large-text/landscape scrolling. No real reservations/payments/profile edits/push sends for QA. No remote deploy in workers. One heavy check/build at a time. Tests first, root observes RED before feature implementation. No source clone/new AVD/commits/pushes.

## Review focus

Cross-user inbox/profile data; stale/error states versus false emptiness; quota/capacity/date/duplicate-submit races; future-order visibility and old QR validity; unknown geography and accessible route/back/logout behavior.

## Shared contracts

- Geography: StoreModel optional `String? governorate` (Arabic canonical labels); root maps `row['governorate'] as String?`, known area fallback in geography logic. Existing StoreListScreen gains optional `governorate`, `initialArea` filters; defaults preserve existing behavior.
- Inbox: NotificationRepository, AppNotification model, SupabaseNotificationRepository and NotificationsScreen(repository, onOpenPurchase(String)). Worker chooses exact method/model names and reports them. Root registers DI and opens linked ConfirmationScreen for the signed-in buyer.
- Account: AccountScreen uses AuthBloc; AuthRepository.updateProfile(name,phone,jawwalPayNumber) returns UserModel from signed-in server RPC. Authenticated state retains authentication during saving/error. Root adds screen to buyer shell and owner account action. Worker owns its fake auth repository, auth tests and profile migration.
- Postpone: QueueRepository and QueueController `postponePurchase(String purchaseId)` returns updated PurchaseModel; `currentOrUpcomingPurchase(String userId,String today)` returns today's order or earliest upcoming uncollected order. Worker owns queue repository/controller, purchase model, receipt persistence, BuyerHomeScreen postponement action/future display, QR validation/scanner switches, tests/fake queue and its SQL. Root edits BuyerHomeScreen geography opening only AFTER worker finishes.
- SQL timestamps: geography root `20261027140000`, inbox `20261027141000`, account `20261027142000`, postpone `20261027143000`; separate files. No dependency on other worker migration except common existing schema. Inbox trigger may react to purchase date change without depending on postponed metadata.

## Tasks

- [x] 1. Root geography: write/red-run tests for canonical explicit/mapped/unknown geography, counts and filtering; add model field/logic/two feature screens/filter optional args and geography migration. Geographic screen callback passes selection into existing store list. Defaults keep original routes/tests working.
- [x] 2. Inbox worker: tests first; tell root RED files ready, wait for root green-light; implement model/repository/Supabase inbox UI, migration/triggers/RLS/read RPCs and SQL tests. No DI/shared navigation/strings/controller edits. Report contracts.
- [x] 3. Account worker: tests first and RED gate; implement account screen/edit sheet, AuthRepository/Bloc/state/save/fake tests and scoped profile RPC migration. No main/shell/DI/queue/shared strings edits. Preserve original login/verification.
- [x] 4. Postpone worker: tests first and RED gate; implement server rules, queue methods/fakes, screen and BuyerHome integration, upcoming booking lookup/receipt update and stale QR rejection. Preserve account/notifications/geography files and shared strings. Ensure reserve/notify/collect cannot bypass future-date rules; serialize store locks consistently.
- [x] 5. Root integrates buyer shell and bells/account owner action, geographic booking entry, DI/inbox routing, logout/reset/refresh and tests. Review each feature and full flow independently, fix material issues, inspect normal/narrow/landscape fixture renders.
- [ ] 6. Serial behavior/full relevant tests and bundled AOT analyzer; SQL tests where local runtime available otherwise static review and explicit unexecuted note. Build same signed package with warm Gradle cache, update existing AVD preserving data, navigate new read-only screens, reopen original Studio; update changelog and ledger. If server migrations need deployment, prepare concrete reviewed migration/runbook before requesting the final deployment decision.

## Pre-flight and ledger

| Tasks/interface | Finding and ruling |
| --- | --- |
| 1/4 SupabaseQueueRepository mapper | Worker4 owns repository; root sends one-line governorate mapper patch after worker4 finishes. No concurrent edit. |
| 4/5 BuyerHomeScreen | Worker4 owns until handoff; root then changes booking entry to governorate selector and wraps shell. |
| 2/3/4 schema | Separate ordered migrations with independent scopes; inbox trigger handles moved purchase without requiring worker4 column. |
| 1/5 navigation | Root owns both and tests defaults plus integrated routes. |
| All tasks/tests | Workers stage tests first, root runs serial RED; after gate workers implement while root checks other groups. No heavy worker tools. |
| Every task/self-consistency | Screens must have reachable actions plus actual repository callbacks; missing deployment is an honest unavailable state, never fake success. |

- Approved scope is the user's previous five-screen description; continuation authorizes implementation. Default postponement quota/capacity rule stated before work.
- Original dirty branch preserved. Existing Studio/AVD may be temporarily stopped for memory and reopened after checks.

- Central RED observed all missing feature APIs/imports through direct verified Dart3.11.4 + flutter_tools.snapshot. Flutter bootstrap SDK stamp was missing; engine_stamp.json/internal engine.version both match425cfb54... and installed Dart3.11.4. Restored only matching SDK metadata; no SDK upgrade/download/replacement.
- Inbox/account/postpone independent review completed. Fixed modal drag during profile save, authenticated receipt fallback, delayed read/stream generation, area trim mismatch, session-private context reset/generation and explicit geographic error/retry. Meaningful regressions observed RED before fixes; reviewed fixes approved.
- First full Flutter run:262passed,2existing skips,3test failures (one lazy landscape assertion, two legacy root navigation/logout targets). Fixed those test drivers to match the approved flow, preserving logout/route privacy assertions. Final full run pending.
- SQL sources reviewed statically; no Docker/psql executable found, so SQL suites have not executed. No remote migrations/push/profile/business writes performed. Four additive/updated SQL migration files require server application before inbox/profile-save/postpone can succeed on the existing deployment.
- Final full Flutter suite: **269 passed, 2 existing skips**, exit 0 (`analysis/new-flow-all-final.log`). All three viewport interaction tests pass. Regression proved RED then GREEN for upcoming uncollected booking taking precedence over collected today; collected-today fallback remains available.
- Final `dart analyze --fatal-infos`: **No issues found**, exit 0 (`analysis/new-flow-analyze-final.log`). `git diff --check` passed (line-ending notices only). Release build and actual AVD/Studio verification are in progress.
- Ordered server handoff: `2026-10-27-server-deployment.md` and `analysis/buyer-flow-server-migrations.sql`. Five labelled production-widget fixture images are packaged in `analysis/buyer-flow-five-screens.zip`; these are controlled previews, not AVD screenshots.
- Release build passed in 4m34s, exit 0 (`analysis/new-flow-release-build.log`), same established lint exclusions. APK 46,482,547 bytes; SHA256 signing certificate remains `62dd228de4e37929064ecb6f4f030af546cfe8a3c9612e923eca2837312b05c2`. Existing Pixel_8 `install -r --abi x86_64` returned Success; no data clear/uninstall.
- Actual runtime: updated owner toolbar/account rendered and account screenshot captured (`analysis/new-flow-runtime-account.png`). Studio open verified title `flutter – governorate_screen.dart`. AVD/IDE simultaneous operation on 6 GB remains severely memory constrained; System UI ANRs recur. Restarted same AVD with 2560 MB/2 cores and same software-renderer flags; did not create a device/project copy. Final full live navigation across all five screens is **not verified**.
- Preserved dead Studio config lock from crashed PID29312 as `.lock-preserved-20261027-29312`; preserved prior system caches. Final IDE uses `analysis/buyer-flow-final.vmoptions` (512 MB heap and fresh short system-cache path); settings/plugins and original source paths retained. Earlier 768 MB IDE plus 3 GB AVD exhausted host/native memory.
- Task 6 remains partial solely for full live navigation and remote SQL execution/deployment. Do not claim inbox/profile saves/postponement live on the server or all five screens device-verified.
