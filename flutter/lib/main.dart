import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/di/injection.dart';
import 'core/i18n/strings.dart';
import 'core/onboarding/onboarding_store.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_notice.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/demo_accounts.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/navigation/buyer_shell.dart';
import 'domain/repositories/notification_repository.dart';
import 'features/queue/owner_dashboard_screen.dart';
import 'domain/models/store_model.dart';
import 'features/queue/queue_controller.dart';
import 'features/verification/photo_capture_screen.dart';
import 'features/verification/waiting_for_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const RaghifApp());
}

class RaghifApp extends StatefulWidget {
  const RaghifApp({super.key, this.authBloc, this.queueController});

  /// Test seam: inject a pre-built bloc instead of resolving one from [sl].
  final AuthBloc? authBloc;
  final QueueController? queueController;

  @override
  State<RaghifApp> createState() => _RaghifAppState();
}

class _RaghifAppState extends State<RaghifApp> {
  late final QueueController _controller;
  late final AuthBloc _authBloc;
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// null while loading, then whether the intro carousel has been seen —
  /// shown once per install, ahead of login/registration.
  bool? _hasSeenOnboarding;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.queueController ??
        (sl.isRegistered<QueueController>()
            ? sl<QueueController>()
            : QueueController());
    _authBloc = (widget.authBloc ?? sl<AuthBloc>())
      ..add(const CheckAuthSessionEvent());
    OnboardingStore().hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _hasSeenOnboarding = seen);
    });
  }

  @override
  void dispose() {
    _authBloc.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      // The root route below swaps between login and home by auth state,
      // but routes pushed on top of it (store list, receipt, registration)
      // would survive the swap: signing out from the store list left it on
      // screen with the login form hidden underneath, one back press away.
      // Crossing the signed-in/signed-out line clears them, whichever screen
      // it happened on.
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, curr) =>
            (prev is Authenticated ? prev.user.id : null) !=
            (curr is Authenticated ? curr.user.id : null),
        listener: (_, _) {
          _controller.resetForSession();
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        },
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'رغيف',
          theme: AppTheme.light,
          // Forced RTL regardless of device locale — this app is Arabic-only.
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (!_hasStarted) {
                return LaunchIdentityScreen(
                  onStart: () => setState(() => _hasStarted = true),
                );
              }
              if (state is AuthInitial) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is Authenticated) {
                // Owners are pre-verified (seeded accounts); buyers go through
                // mock ID/selfie capture once before they can buy.
                if (!state.user.isOwner && !state.user.isVerified) {
                  return PhotoCaptureScreen(
                    kind: PhotoCaptureKind.id,
                    onContinue: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoCaptureScreen(
                          kind: PhotoCaptureKind.selfie,
                          onContinue: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const WaitingForVerificationScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final demoUser = DemoUser(
                  id: state.user.id,
                  phone: state.user.phone,
                  pin: '',
                  role: state.user.isOwner ? UserRole.owner : UserRole.buyer,
                  name: state.user.name,
                  jawwalPayNumber: state.user.jawwalPayNumber,
                );

                return state.user.isOwner
                    ? _OwnerHome(
                        controller: _controller,
                        ownerId: state.user.id,
                      )
                    : BuyerShell(
                        key: ValueKey(state.user.id),
                        controller: _controller,
                        currentUser: demoUser,
                        notifications: sl.isRegistered<NotificationRepository>()
                            ? sl<NotificationRepository>()
                            : null,
                      );
              }

              // Unauthenticated, AuthLoading (session check or a login/register
              // submit in flight), AuthFailure, AuthSwitchToRegister — all show
              // the login form (after the once-per-install intro carousel);
              // LoginScreen reads AuthBloc state itself for its own
              // loading/error UI.
              if (_hasSeenOnboarding == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (_hasSeenOnboarding == false) {
                return OnboardingScreen(
                  onDone: () => setState(() => _hasSeenOnboarding = true),
                );
              }
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}

class LaunchIdentityScreen extends StatefulWidget {
  const LaunchIdentityScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<LaunchIdentityScreen> createState() => _LaunchIdentityScreenState();
}

class _LaunchIdentityScreenState extends State<LaunchIdentityScreen> {
  static const _cream = Color(0xFFF6F0E5);
  static const _bread = Color(0xFFB8742A);
  static const _gold = Color(0xFFD9A441);
  static const _ink = Color(0xFF2E3B2E);
  bool _pressed = false;

  static const _loafSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" fill="none">
  <path d="M16 46C16 31.6406 27.6406 20 42 20C56.3594 20 68 31.6406 68 46C68 53.732 61.732 60 54 60H30C22.268 60 16 53.732 16 46Z" fill="#B8742A"/>
  <path d="M32 28C35.5 33 37 40 36 47M44 26C48 32 49 39 48 47M56 29C58.5 34 59 40 58 46" stroke="#F6F0E5" stroke-width="3" stroke-linecap="round"/>
  <path d="M38 14C37 11 39 8 38 5M46 13C45 10 47 7 46 4" stroke="#D9A441" stroke-width="2" stroke-linecap="round" opacity="0.7"/>
</svg>''';

  static const _wheatSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#B8742A">
  <path d="M12 2C12 2 10.5 5.5 12 8C13.5 5.5 12 2 12 2ZM8.5 6.5C7.2 7.8 7.2 9.8 8.5 11.1C9.8 12.4 11.8 12.4 13.1 11.1C11.8 9.8 11.8 7.8 8.5 6.5ZM15.5 6.5C18.8 7.8 18.8 9.8 17.5 11.1C16.2 12.4 14.2 12.4 12.9 11.1C14.2 9.8 14.2 7.8 15.5 6.5ZM12 10C12 10 10.5 13.5 12 16C13.5 13.5 12 10 12 10ZM12 16V22H11V16H12Z"/>
</svg>''';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _line() => Container(
    width: 32,
    height: 2,
    decoration: BoxDecoration(
      color: _gold.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _dot(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _cream,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _cream,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _cream,
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SizedBox(
              width: constraints.maxWidth,
              height: (constraints.maxHeight * 0.85).clamp(
                500.0 * MediaQuery.textScalerOf(context).scale(1),
                double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 4,
                        sigmaY: 4,
                        tileMode: ui.TileMode.decal,
                      ),
                      child: Container(
                        width: 64,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              width: 144,
                              height: 144,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: 24,
                                  sigmaY: 24,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _gold.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 112,
                              height: 112,
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1FB8742A),
                                    offset: Offset(0, 10),
                                    blurRadius: 25,
                                    spreadRadius: -5,
                                  ),
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    offset: Offset(0, 8),
                                    blurRadius: 10,
                                    spreadRadius: -6,
                                  ),
                                ],
                              ),
                              child: SvgPicture.string(
                                _loafSvg,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'رغيف',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 40,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _line(),
                            const SizedBox(width: 8),
                            SvgPicture.string(
                              _wheatSvg,
                              width: 16,
                              height: 16,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 8),
                            _line(),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _dot(6, _gold.withValues(alpha: 0.7)),
                                const SizedBox(width: 12),
                                _dot(10, _bread),
                                const SizedBox(width: 12),
                                _dot(6, _gold.withValues(alpha: 0.7)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Listener(
                              onPointerDown: (_) =>
                                  setState(() => _pressed = true),
                              onPointerUp: (_) =>
                                  setState(() => _pressed = false),
                              onPointerCancel: (_) =>
                                  setState(() => _pressed = false),
                              child: AnimatedScale(
                                scale: _pressed ? 0.95 : 1,
                                duration: const Duration(milliseconds: 150),
                                child: Material(
                                  color: _bread,
                                  elevation: 3,
                                  shadowColor: _bread.withValues(alpha: 0.3),
                                  shape: const StadiumBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: widget.onStart,
                                    child: const SizedBox(
                                      height: 56,
                                      width: double.infinity,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'ابدأ التجربة',
                                            style: TextStyle(
                                              fontFamily: 'IBMPlexSansArabic',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_back,
                                            size: 18,
                                            color: Colors.white,
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves which store this owner manages before showing the dashboard.
///
/// Used to be a hardcoded `demoOwnerStoreId = 1`, which only worked because
/// every install seeded its own store #1 locally. Ownership is a server
/// fact now (`stores.owner_id`), so it has to be asked for.
class _OwnerHome extends StatefulWidget {
  const _OwnerHome({required this.controller, required this.ownerId});

  final QueueController controller;
  final String ownerId;

  @override
  State<_OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<_OwnerHome> {
  late Future<StoreModel?> _store;

  @override
  void initState() {
    super.initState();
    _store = widget.controller.storeForOwner(widget.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreModel?>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: OfflineNotice(
              onRetry: () => setState(() {
                _store = widget.controller.storeForOwner(widget.ownerId);
              }),
            ),
          );
        }
        final store = snapshot.data;
        if (store == null) {
          // An owner account with no store attached. Better to say so than
          // to guess at a store and let them manage someone else's queue.
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  Strings.noStoreForOwner,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return OwnerDashboardScreen(
          controller: widget.controller,
          storeId: store.id,
        );
      },
    );
  }
}
