import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gallery_app/services/folder_lock_service.dart';
import 'package:gallery_app/services/app_lock_service.dart';
import 'package:gallery_app/services/notification_service.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'utils/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow Google Fonts to fetch fonts
  GoogleFonts.config.allowRuntimeFetching = true;

  // Initialize notification service
  await NotificationService.instance.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class SafeQuillLocalizationsDelegate
    extends LocalizationsDelegate<FlutterQuillLocalizations> {
  const SafeQuillLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<FlutterQuillLocalizations> load(Locale locale) async {
    try {
      if (FlutterQuillLocalizations.delegate.isSupported(locale)) {
        return await FlutterQuillLocalizations.delegate.load(locale);
      }
    } catch (_) {}
    return await FlutterQuillLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<FlutterQuillLocalizations> old,
  ) => false;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  void _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      FolderLockService.instance.lockSession();
      AppLockService.instance.onAppPaused();
    }
    if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    }
  }

  Future<void> _checkAppLock() async {
    final appLock = AppLockService.instance;
    final isEnabled = await appLock.isEnabled();
    if (isEnabled && appLock.isLocked) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null) {
        AppLockService.showLockScreen(ctx);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Hub',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      localizationsDelegates: const [
        SafeQuillLocalizationsDelegate(),
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''),
        ...FlutterQuillLocalizations.supportedLocales,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (var supported in supportedLocales) {
            if (supported.languageCode == locale.languageCode) {
              return supported;
            }
          }
        }
        return const Locale('en', '');
      },
      builder: (context, child) {
        return SafeTextScaleScope(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: SplashScreen(
        setThemeMode: _setThemeMode,
      ),
    );
  }
}
