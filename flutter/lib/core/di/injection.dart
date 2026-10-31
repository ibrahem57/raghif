import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';
import '../config/env.dart';
import '../notifications/fcm_service.dart';
import '../notifications/notification_service.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_queue_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/queue_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/supabase_notification_repository.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/queue/queue_controller.dart';

final GetIt sl = GetIt.instance;

/// Supabase is required, not optional.
///
/// The old `USE_SUPABASE` flag picked between a Supabase path and a
/// drift-only one that seeded and decided everything on-device. Keeping
/// both meant two disagreeing sources of truth, which is what shipped the
/// batch-number mismatch. There is one path now, and no on-device database:
/// every screen reads Supabase.
Future<void> initDependencies() async {
  await Env.load();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  sl.registerSingleton<SupabaseClient>(Supabase.instance.client);

  sl.registerSingleton<NotificationService>(NotificationService.instance);
  await sl<NotificationService>().init();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final fcmService = FcmService(sl<SupabaseClient>());
  sl.registerSingleton<FcmService>(fcmService);
  await fcmService.init();

  sl.registerSingleton<AuthRepository>(
    SupabaseAuthRepository(
      client: sl<SupabaseClient>(),
      fcmService: sl<FcmService>(),
    ),
  );

  sl.registerSingleton<QueueRepository>(
    SupabaseQueueRepository(client: sl<SupabaseClient>()),
  );

  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl<AuthRepository>()),
  );
  sl.registerSingleton<NotificationRepository>(
    SupabaseNotificationRepository(client: sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<QueueController>(
    () => QueueController(sl<QueueRepository>()),
  );
}
