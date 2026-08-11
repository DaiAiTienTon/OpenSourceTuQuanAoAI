import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'package:tuquanapai/service/theme_service.dart';

import 'core/theme.dart';
import 'service/Session_service.dart';
import 'service/Weather_service.dart';
import 'viewmodels/Ai_History_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/health_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/outfit_eval_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/wardrobe_viewmodel.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/main_shell.dart';
import 'views/screens/register_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  try {
    await SharedPreferences.getInstance();
    debugPrint('✅ SharedPreferences đã thông luồng thành công!');
  } catch (e) {
    debugPrint('⚠️ Lỗi khởi tạo SharedPreferences: $e');
  }
  runApp(const StyleAIApp());
}

class StyleAIApp extends StatelessWidget {
  const StyleAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()..init()),

        // ── Core services ────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => SessionService()),
        ChangeNotifierProvider(create: (_) => WeatherService()),

        // ── AuthViewModel ────────────────────────────────────────────────
        ChangeNotifierProxyProvider<SessionService, AuthViewModel>(
          create: (ctx) => AuthViewModel(session: ctx.read<SessionService>()),
          update: (ctx, session, prev) => prev!..updateSession(session),
        ),

        // ── WardrobeViewModel ────────────────────────────────────────────
        ChangeNotifierProxyProvider<SessionService, WardrobeViewModel>(
          create: (ctx) =>
              WardrobeViewModel(session: ctx.read<SessionService>()),
          update: (ctx, session, prev) => prev!..updateSession(session),
        ),

        // ── HealthViewModel ──────────────────────────────────────────────
        ChangeNotifierProxyProvider<SessionService, HealthViewModel>(
          create: (ctx) =>
              HealthViewModel(session: ctx.read<SessionService>()),
          update: (ctx, session, prev) => prev!..updateSession(session),
        ),

        // ── ProfileViewModel ─────────────────────────────────────────────
        ChangeNotifierProxyProvider<SessionService, ProfileViewModel>(
          create: (ctx) =>
              ProfileViewModel(session: ctx.read<SessionService>()),
          update: (ctx, session, prev) => prev!..updateSession(session),
        ),

        // ── AiHistoryViewModel ───────────────────────────────────────────
        ChangeNotifierProxyProvider<SessionService, AiHistoryViewModel>(
          create: (ctx) =>
              AiHistoryViewModel(session: ctx.read<SessionService>()),
          update: (ctx, session, prev) => prev!,
        ),

        // ── HomeViewModel ────────────────────────────────────────────────
        ChangeNotifierProxyProvider3<SessionService, WeatherService,
            AiHistoryViewModel, HomeViewModel>(
          create: (ctx) => HomeViewModel(
            session: ctx.read<SessionService>(),
            weather: ctx.read<WeatherService>(),
            history: ctx.read<AiHistoryViewModel>(),
          ),
          update: (ctx, session, weather, history, prev) => prev!,
        ),

        // ── OutfitEvalViewModel ──────────────────────────────────────────
        ChangeNotifierProxyProvider4<SessionService, WeatherService,
            HealthViewModel, AiHistoryViewModel, OutfitEvalViewModel>(
          create: (ctx) => OutfitEvalViewModel(
            session: ctx.read<SessionService>(),
            weatherService: ctx.read<WeatherService>(),
            healthViewModel: ctx.read<HealthViewModel>(),
            history: ctx.read<AiHistoryViewModel>(),
          ),
          update: (ctx, session, weather, health, history, prev) => prev!,
        ),
      ],
      

      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          final t = themeService.current;
          return MaterialApp(
            title: 'StyleAI',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('vi', 'VN'),
            theme: ThemeData(
              fontFamily: 'sans-serif',
              colorScheme: ColorScheme.fromSeed(seedColor: t.primary),
              useMaterial3: true,
            ),
            home: const _AppRouter(),
          );
        },
      ),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _tryRestore();
  }

  Future<void> _tryRestore() async {
    await context.read<SessionService>().tryRestoreSession();
    // Khởi tạo model ngầm ngay từ đầu
    GemmaThemeService.instance.initialize();
    if (mounted) setState(() => _restoringSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authVM = context.watch<AuthViewModel>();

    if (authVM.isAuthenticated) {
      final weatherService = context.read<WeatherService>();
      if (weatherService.status == WeatherStatus.idle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          weatherService.fetchWeather().then((_) {
            if (mounted) _scheduleThemeGeneration(context);
          });
        });
      }
      return const MainShell();
    }

    return switch (authVM.screen) {
      AuthScreen.login => const LoginScreen(),
      AuthScreen.register => const RegisterScreen(),
      _ => const LoginScreen(),
    };
  }

  /// Delay 3 giây sau khi UI ổn định mới chạy inference.
  /// Tránh tranh RAM với quá trình restore session + render UI lần đầu.
  /// Quan trọng trên thiết bị thấp như Samsung A03.
  void _scheduleThemeGeneration(BuildContext context) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _triggerThemeGeneration(context);
    });
  }

  /// Build ThemeContext đầy đủ từ tất cả data sources:
  /// thời tiết + sức khoẻ + thông tin cá nhân + sở thích người dùng
  void _triggerThemeGeneration(BuildContext context) {
    final weather = context.read<WeatherService>();
    final health = context.read<HealthViewModel>();
    final session = context.read<SessionService>();
    final user = session.currentUser;
    final pref = session.userPreference;

    final themeCtx = ThemeContext(
      // ── Môi trường ──────────────────────────────────────────────────
      hourOfDay: DateTime.now().hour,
      tempC: weather.weather?.tempC,
      weatherCondition: weather.weather?.description,

      // ── Sức khoẻ ────────────────────────────────────────────────────
      heartRateBpm: double.tryParse(health.data.heartRate),
      sleepHours: double.tryParse(health.data.sleep),

      // ── Tủ quần áo ──────────────────────────────────────────────────
      wardrobeItemCount: session.clothingItems.length,

      // ── Thông tin cá nhân ────────────────────────────────────────────
      userName: user?.name,
      userAge: user?.age,

      // ── Sở thích (stylePreference làm màu yêu thích nếu có) ─────────
      favoriteColor: pref?.stylePreference,
      userHobbies: pref?.hobbies ?? [],
    );

    debugPrint('[ThemeGen] Triggering with ctx: ${themeCtx.toPromptContext()}');
    context.read<ThemeService>().generateTheme(themeCtx);
  }
}