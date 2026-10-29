# Remaining Stitch Screens Implementation Plan

> **For agentic workers:** Use subagent-driven-development for the disjoint screen groups, then central serial verification and final review. Edit the existing checkout directly, as the user explicitly requires.

**Goal:** Restyle the remaining 12 functional interfaces in the current Flutter application to the established cream Stitch style and run the updated package on the existing Pixel_8.

**Architecture:** Keep existing Dart screen locations, routes, controllers, fields, validation and service calls. Reuse the existing theme, local loaf/bread assets, IBM Plex Arabic, white rounded cards and pill buttons. Preserve all prior dirty changes; no new app, checkout, entrypoint, backend or AVD.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4, existing Material/widgets, camera and QR plugins, existing payment simulation and Supabase repositories.

**Spec:** User's approved existing screen designs and supplied local `reference/stitch_ragheef_app_onboarding_ui` exports. Existing cream style takes precedence over original blue UI spec.

## Global Constraints

- Cream #F6F0E5, accent #884E00, bread #B8742A, ink #2E3B2E, gold #D9A441; existing AppColors/AppTypography, IBM Plex Arabic, Arabic RTL.
- Keep text readable (15sp floor), labelled >=48dp touch targets, keyboard clearance, safe areas, large-text and landscape scrolling.
- Preserve camera-only ID/back and selfie/front capture, retake/continue callbacks, verification timer and AuthBloc event. Do not portray simulated verification as real identity matching.
- Preserve purchase availability/daily limits, real stock, existing payment number/OTP/cooldown/results and QR redemption guards. Do not replace these with Stitch sample values or fake actions.
- Preserve owner live data, search, batch settings/confirmation, receipt status actions, scan torch/lifecycle, customer/history queries and navigation.
- No real booking, payment, inventory write, verification approval or notification send merely to preview screens. Test doubles are confined to tests.
- One heavy test/analyzer/build at a time; workers only edit assigned files and report commands for central execution.
- No commits, pushes or additional source copies. Existing signing/package/data must remain intact when updating the AVD.

## Review Focus

- Long names, IDs, phone numbers and metadata wrap without obscuring actions.
- Forms/OTP and bottom CTAs remain reachable with keyboard, 320dp width and 1.5x text.
- All loading/empty/error states and unavailable/cancelled actions retain honest labels and working callbacks.
- QR scanner remains a real camera with a clear viewport; do not change scan/owner/status validation.
- Simulated payment and verification behavior stays unchanged and its wording does not imply newly implemented real integration.

## Tasks

- [x] 1. Verification group: restyle `flutter/lib/features/verification/photo_capture_screen.dart` (ID and selfie) and `waiting_for_verification_screen.dart` (waiting/result). Use existing brand identity, photo framing and progress/status cards; no dedicated equivalent exists in Stitch, so derive from approved registration/phone-confirmation/success patterns. Preserve callbacks and camera request semantics. Add narrow/large-text coverage for these screens if absent.
- [x] 2. Payment group: restyle existing `features/payment/payment_{number,otp,success}_screen.dart`; reference `11_jawwal_pay`, `11_electronic_payment`, `04_phone_verification`, cream success patterns. Preserve simulation, OTP digits, resend/cooldown and route bool results. Existing `test/features/payment/payment_flow_test.dart` remains the behavioral contract; add responsive coverage where needed.
- [x] 3. Owner management group: existing `features/queue/owner_{queue,customers,history}_screen.dart` (history includes separate day route). References `04_2`, `05`, `06`, `07`, `11`, extending established dashboard. Keep actual fields/actions only, no new reports/revenue/delay features. Validate owner queue/history/customer tests and narrow scrolling.
- [x] 4. Root purchase/scanner: existing `features/queue/purchase_screen.dart` and `qr_scanner_screen.dart`; references `10_booking_confirmation`, `08`, `09`. Purchase uses real bakery/summary/guarded payment CTA; scanner keeps camera viewport, torch, real result states and rescan/back behavior. Validate purchase/payment/QR tests.
- [x] 5. Integrate and review all 12 interfaces; add production-widget render/interaction coverage for small, normal and landscape sizes. Run focused behavior/a11y tests serially, bundled AOT `dart analyze --fatal-infos`, and diff checks. Inspect generated fixture screenshots against source references. Final independent code review and resolve material findings.
- [x] 6. Build from the same source via R: alias and Java21, original 1536MB Gradle heap; use proven offline :app:assembleRelease path (record lint exclusions/warnings honestly). Verify package and unchanged signature, update existing AVD with install -r --abi x86_64, run using established software renderer flags, safely navigate without business writes. Reopen original Android Studio project with Pixel_8 selected.
- [x] 7. Add one task changelog entry, record actual runtime/test coverage and any remaining limitation, leave project/emulator showing the result.

## Ledger

- Ruling: user explicitly says same style/method and original project; no new design approval, app clone or worktree is appropriate.
- Ruling: 12 functional interfaces map to 10 existing files because photo capture is reused for ID/selfie and history file includes a separate day screen. Dialogs/loading/error variants are not separate screens.
- Ruling: Stitch has no direct ID/selfie equivalent; extend the approved registration/verification card and success visual patterns without introducing backend functionality.
- Environment: Windows 6GB RAM; close task-owned Studio/AVD while testing/building and reopen afterward. Prior permission covers temporary Chrome/VS Code/Claude closure if memory requires it; preserve unsaved work.
- 2026-10-27 resume: verification/payment saved implementation reviewed with no production regressions; completed owner management, purchase and scanner styling directly in existing files. Independent scoped review approved owner/purchase/scanner.
- Verification: first focused payment/verification/purchase run passed 26 tests. Responsive review rendered all 12 functional interfaces (13 images including waiting/result); fixed test-only lazy finder and missing post-scroll frame handling after observed failures.
- Ruling: existing collected-row `undoReceived` label calls idempotent `collectPurchase`; repository/backend provide no undo API. Preserve existing callback/backend behavior as requested rather than inventing reversal. New responsive assertion now tests actual idempotence; this pre-existing label limitation remains.
- Scanner fixture uses production camera-unavailable state through a platform double. It does not establish live camera decoding. Live AVD navigation remains required after update.

- Final central verification 2026-10-27: 161 passed, 2 pre-existing skips across visual/queue/payment/verification/a11y; bundled dart analyze --fatal-infos: No issues found. Build excludes Android lint tasks as prior environment workaround; no Android-lint pass claimed.

- Completion 2026-10-27: offline :app:assembleRelease passed after preserving/rebuilding Gradle transform cache (D8 metadata warnings, lint exclusions retained). APK 46,417,003 bytes, package com.raghif.raghif version1.0.0+2; unchanged SHA256 signing certificate 62dd228de4e37929064ecb6f4f030af546cfe8a3c9612e923eca2837312b05c2.
- Existing Pixel_8 booted, install -r --abi x86_64 succeeded; actual app splash, owner dashboard and updated empty owner queue observed. Owner data/session retained (296/300, no new purchases/notifications/stock changes for preview). Android System UI startup ANR resolved by Wait. Foreground activity remains the original MainActivity.
- Studio opened original source/flutter project on owner_queue_screen.dart (process title verified). Fresh IDE system cache stitch-remaining-open-20261027 resolved stale old .port without deleting it or changing settings/plugins. Runtime sessions left running.
- Windows Computer Use ended because Chrome URL could not be verified by the tool. No further Windows UI inputs were issued through that tool; safe Android CLI/build/process launch paths completed the task. No claim of an additional desktop visual inspection.
- Final artifacts: analysis/remaining-runtime-owner-final.png actual AVD screenshot; analysis/raghif-remaining-screens.zip contains 13 labelled fixture images for 12 interfaces. 161 tests passed, 2 existing skips; final analyzer clean. Changelog updated. No commit/push/source clone/new AVD.