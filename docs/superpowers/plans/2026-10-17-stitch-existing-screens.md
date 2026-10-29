# Existing Raghif Stitch Screens Implementation Plan

> **For agentic workers:** Use the subagent-driven-development workflow for the independent screen groups below, followed by integration and a whole-change review. Work directly in the existing checkout, as explicitly requested by the user.

**Goal:** Restyle the eight requested screen functions to match the supplied Stitch references while retaining the current Flutter screens and application behavior.

**Architecture:** Keep every screen in its current Dart file and preserve its existing blocs, controllers, subscriptions, validation, callbacks, routes, and QR payload. Extend the existing shared theme/widgets and use supplied artwork as local assets. No new application, source checkout, emulator, backend, or alternative runtime entrypoint.

**Tech Stack:** Existing Flutter 3.41.6 / Dart 3.11.4, Material, flutter_svg, Supabase, qr_flutter.

**Spec:** User's screen mapping in this conversation; local `reference/stitch_ragheef_app_onboarding_ui` HTML and screenshots. Prefer cream variants consistent with the approved splash. Original UI_SPEC blue styling is superseded for this request.

## Global Constraints

- Edit `source/flutter` directly; preserve existing pending splash/environment changes.
- Keep Arabic RTL, source language and screen locations.
- Cream #F6F0E5, bread #B8742A, deep brown #884E00, ink #2E3B2E, gold #D9A441, olive/sage status colors, white rounded cards, IBM Plex Sans Arabic.
- Preserve identity/PIN/OTP authentication and all registration inputs despite different example fields in Stitch.
- Preserve stock/availability guards, search, area filtering, pinning, current order streams, QR data, image save/share, owner settings and write confirmations.
- Never replace real backend values with Stitch examples or add inert navigation/actions.
- Keep readable text, labelled >=48dp targets, scrolling, keyboard clearance, and safe areas.
- No real registration, booking, payment, inventory edit or notification send for visual verification without specific authorization.
- One build/test process at a time on this low-memory machine; agents edit disjoint files and request central test execution.
- No automatic commits/pushes; keep result reviewable in the current working tree.

## Review Focus

- Small screens/landscape/large text must scroll without overflow, including forms and QR details.
- Unavailable bread and asynchronous loading/errors must remain actionable and honest.
- Current order status and receipt must use actual model data and QR payload.
- Auth field validation and PIN recovery must retain input and error placement.
- Owner edits/dirty-state/save and destructive close confirmation must remain intact.

## Tasks

- [x] 1. Shared style/assets (root): existing `core/theme/app_{colors,typography,theme,shapes}.dart`, existing button/card widgets, pubspec fonts, local reference bread artwork and loaf SVG. Retain existing behavioral and a11y checks; verify responsive rendering of the production widgets.
- [x] 2. Onboarding/auth: edit existing `features/onboarding/onboarding_screen.dart`, `features/auth/{login,registration}_screen.dart`. References `02_1_onboarding_1`, `02_2_onboarding_2`, `02_3_onboarding_3`, `03_registration`, `01_2`/`01_1`. Photo cards/brand header, white forms, pill CTA, original callbacks/fields; run existing focused tests centrally.
- [x] 3. Store browse/details (root): existing `features/queue/{store_list,store_details}_screen.dart`. References `08_distribution_points`, `09_distribution_point_details`. Local bread hero/thumbnail, search/location header, rounded white store cards, stock/time pills, preserved live state and actions. Verify existing search, unavailable-state and purchase-route tests.
- [x] 4. Order/receipt: existing `features/queue/{buyer_home,confirmation}_screen.dart` and `receipt_card.dart`. References `13_1`, `13_2`, `12_success_qr_pass_2`. Success mark, QR-first receipt, live status card and progress strip; preserve save/share/streams/status. Verify existing buyer/confirmation/QR tests.
- [x] 5. Owner dashboard: existing `features/queue/owner_dashboard_screen.dart`, references `02_2`/`02_1`. Store identity, allocation progress, three stats, gate card, editable settings, existing quick actions; no invented data. Verify existing owner dashboard tests.
- [x] 6. Integrate/review/test: review each screen group against its source reference and preserved behavior; run analyze and focused/full relevant tests serially, fix regressions. Add meaningful responsive tests only where changes warrant them. Fresh final review of whole UI change.
- [x] 7. Build/run/show: update the existing package on existing Pixel_8 using the same signing key/data. Review actual screenshots, exercise safe navigation without business writes, keep original project open in Android Studio and emulator on updated UI. Record exact runtime coverage and any backend/access limitation.
- [x] 8. Add one completion changelog entry and verify git diff/status; deliver concise Arabic outcome with screenshot evidence.

## Ledger

- Plan created after inspecting current theme, all screen mappings, and Stitch contact sheets.
- Ruling: work in the existing dirty checkout, not an isolated checkout — explicit user requirement; preserve previous splash edits.
- Ruling: preserve current authentication/business fields and functional controls even where Stitch omits them — mapping is functional equivalence and user requested styling of the original application.
- Ruling: use cream alternatives across requested screens for continuity with the approved splash; preserve functional status distinctions.

- 2026-10-24: Eight requested screen functions restyled in their existing Dart files, using the supplied cream Stitch palette, IBM fonts, loaf identity and local bread artwork. Existing authentication fields, backend/controller actions and QR payload retained.
- 2026-10-24 verification: 91 focused/a11y/QR cases passed (2 pre-existing skips); 14 confirmation/list cases passed; all three production-screen viewport tests passed after correcting lazy-list scrolling in the test harness. Test fixtures use in-memory repositories only and are not device screenshots.

- 2026-10-24: dart analyze --fatal-infos completed with No issues found (exit 0). Flutter's JIT analysis-server process was stopped due to severe memory pressure and replaced with the bundled Dart AOT analyzer.

- 2026-10-24 build: :app:assembleRelease succeeded (4m36s); APK updated at 13:43, package com.raghif.raghif / 1.0.0+2, signing SHA256 unchanged: 62dd228de4e37929064ecb6f4f030af546cfe8a3c9612e923eca2837312b05c2. Native build emitted existing-toolchain Kotlin metadata warnings; Android lint/annotation-export tasks were excluded, so Android Lint is not a verified check.
- Environment repair: Android Studio was replaced by 2026.1.3 with Java25. Installed verified Microsoft OpenJDK21 ZIP under Downloads and selected it for Flutter. Preserved Gradle transforms cache (8908 missing metadata files) and regenerated it. A 768MB trial heap was insufficient for JetifyTransform; restored original 1536MB Gradle heap. Gradle stopped before launching the existing Pixel_8 AVD.


- Runtime verified 2026-10-24: existing APK updated with adb install -r --abi x86_64 (Success); preserved app data. Actual emulator navigation: splash -> shared login -> registration -> existing demo buyer -> current-order empty state -> live bakery list -> real bakery details -> existing demo owner dashboard (296/300, pending0). No real registration, reservation, inventory update or notification send was performed. QR/current-order populated states and onboarding verified through production-widget fixtures; no active booking exists for the demo buyer today.
- Device workaround: API37.1 SurfaceView/Impeller repeatedly rejected differently sized buffers and SystemUI ran out of guest memory at2GB. Existing Pixel_8 now uses3GB; the existing main.dart Android Studio launch config uses --enable-software-rendering --no-enable-impeller. No production manifest/renderer change or alternative app entrypoint. User authorized closing Chrome, VS Code and Claude to recover host memory.
- Android Studio2026.1.3 opened original project and modified onboarding_screen.dart with Flutter94.0.0, Dart506.1.0 and SDK3.41.6/3.11.4. Diagnosed stale config .lock via JVM thread dump; preserved stale lock after confirming its old PID was absent, then launched with separate IDE cache (source unchanged).
- Added one changelog entry for this screen task; prior splash/environment changes preserved. No commit or push.

- Final IDE check: original project open with syntax-highlighted modified Dart source; toolbar explicitly selected Pixel 8 (mobile). External emulator left on the updated owner dashboard. Current process log has no Unhandled Exception or FATAL EXCEPTION.
