# Buyer Stitch Flow — approved scope

The user approved creating the five proposed missing screens in the original Flutter project, retaining its language, layers, file organization and established Stitch styling. Existing source edits remain intact; no source clone, new application, worktree or emulator.

## Screens and navigation

1. Select governorate: five labelled Gaza governorates, actual store counts, no fabricated availability. Select a governorate to open its areas.
2. Select area: search actual mapped areas, show actual store counts; continue to the existing filtered store list. Unknown store geography remains explicitly uncategorized and reachable through browse-all. Prefer explicit server governorate; known area fallback supports the existing deployment without inventing locations.
3. Notifications: persisted server inbox, actual purchase-confirmed/ready/postponed events, read/unread, mark all read, open linked current receipt. Loading, empty and unavailable/retry are separate. Never fabricate payment notifications or send real notifications for previews.
4. Account: actual authenticated name, national ID, phone and wallet; copy ID; edit name/phone/wallet through validated server save; ID/role/status read-only; preserve existing logout confirmation. A save failure must retain the authenticated session, entered values and open route. Phone update must not falsely claim SMS verification.
5. Postpone: today's uncollected booking, same bakery, tomorrow's date, no second charge. Explicit confirmation, loading/re-entry guard, cancel without write, authoritative errors. Show the moved booking in My Booking and issue its updated QR.

Buyer navigation: Home (geographic selection), My Booking (existing BuyerHomeScreen), Account. Notifications bell opens the inbox from the shell; owners can access account/inbox without acquiring buyer booking routes. Existing owner flow stays intact.

## Rulings

- User approved proceeding instead of answering the last quota question: choose the conservative rule stated in commentary. Tomorrow's deferred order consumes tomorrow's one-bag quota and store capacity. Reject an existing tomorrow booking, exhausted capacity, unauthorized/collected/old/already deferred bookings. One postponement maximum. Server date is authoritative.
- No guaranteed queue position or ready time: tomorrow receives its real batch and starts waiting; no invented notification timing.
- Backend remains authoritative. Prepare additive SQL migrations, permission-scoped RPCs, SQL tests and deployment notes. Do not silently simulate missing server functionality or perform business writes for visual QA. No remote schema deployment without a concrete reviewed deployment step.
- Keep existing payment/verification simulation unchanged. Do not add providers, languages, packages or speculative reports.
- Geographic assignment cannot be inferred for arbitrary unknown areas. Add nullable governorate metadata and fallback only for a documented list of known neighborhoods; unknowns stay accessible.

## Organization and design

Keep `domain/models`, `domain/repositories`, `data/repositories`, `features/<feature>`, existing DI/AuthBloc/QueueController patterns. Notification inbox is a separate repository; reservation rules remain in QueueRepository/Postgres. Account changes extend AuthRepository/AuthBloc while authenticated. Reuse AppColors/AppTypography/AppCard/PrimaryButton/SecondaryButton, loaf SVG and IBM Plex Sans Arabic, RTL, cream #F6F0E5, accessible accent #884E00, white rounded cards, >=48dp actions, readable >=15sp text. Small/large text, keyboard, landscape and long data must scroll.

## Required evidence

Meaningful behavioral tests for geography/filter/back, inbox read/open/error/isolation, profile save/failure/session, postponement quotas/ownership/state/QR invalidation and navigation. Server tests cover RLS and transactional rules. Central serial tests/analyzer/build under 6GB RAM; inspect production widget renders and actual original AVD runtime. Never claim SQL execution if no local database runtime exists. Record deployment limitations precisely.
