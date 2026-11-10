import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glide/core/di/injection.dart';
import 'package:glide/core/widgets/error_views.dart';
import 'package:glide/features/camera/presentation/cubit/camera_cubit.dart';
import 'package:glide/features/detection/presentation/cubit/detection_cubit.dart';
import 'package:glide/features/detection/presentation/pages/detection_page.dart';
import 'package:glide/features/home/presentation/pages/home_page.dart';
import 'package:glide/features/navigation/presentation/cubit/navigation_cubit.dart';
import 'package:glide/features/navigation/presentation/pages/navigation_page.dart';
import 'package:glide/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:glide/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:glide/features/onboarding/presentation/widgets/onboarding_gate.dart';
import 'package:glide/features/settings/presentation/pages/settings_page.dart';
import 'package:glide/features/text_reader/presentation/cubit/text_reader_cubit.dart';
import 'package:glide/features/text_reader/presentation/pages/text_reader_page.dart';
import 'package:glide/services/camera/camera_service.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const detection = '/detect';
  static const textReader = '/read';
  static const navigation = '/navigate';
  static const settings = '/settings';
  static const welcome = '/welcome';
}

GoRouter createRouter() => GoRouter(
  errorBuilder: (context, _) =>
      ErrorScreen(onGoHome: () => context.go(AppRoutes.home)),
  routes: [
    GoRoute(
      path: AppRoutes.home,
      // First launch shows the tutorial (with the safety notice) instead.
      builder: (_, _) => BlocProvider(
        create: (_) => getIt<OnboardingCubit>(),
        child: const OnboardingGate(child: HomePage()),
      ),
      routes: [
        GoRoute(
          path: AppRoutes.detection.substring(1),
          // Fresh cubits per visit; closing them releases the camera.
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<CameraCubit>()..start()),
              BlocProvider(create: (_) => getIt<DetectionCubit>()),
            ],
            child: const DetectionPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.textReader.substring(1),
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => getIt<CameraCubit>()..start(use: CameraUse.text),
              ),
              BlocProvider(create: (_) => getIt<TextReaderCubit>()),
            ],
            child: const TextReaderPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.navigation.substring(1),
          // Closing the cubit stops GPS and the compass.
          builder: (_, _) => BlocProvider(
            create: (_) => getIt<NavigationCubit>()..start(),
            child: const NavigationPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.welcome.substring(1),
          builder: (_, _) => BlocProvider(
            create: (_) => getIt<OnboardingCubit>(),
            child: Builder(
              builder: (context) =>
                  OnboardingPage(onFinished: () => context.pop()),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings.substring(1),
          builder: (_, _) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
