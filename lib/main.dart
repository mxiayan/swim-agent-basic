import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'backend/firebase/firebase_config.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();

  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  /// Single instance; palette matches [LightModeTheme] in `flutter_flow_theme.dart`.
  static final LightModeTheme _lightTheme = LightModeTheme();

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  StreamSubscription<User?>? _authSwimmerSub;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  bool displaySplashImage = true;

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);

    // GoRouter treats `AppStateNotifier.user == null` as still loading and keeps
    // the splash visible forever. Sync Firebase auth into the notifier.
    // Also set global [currentUser] — auth_util / loggedIn use it; it was only
    // updated by the unused swimAgentBasicFirebaseUserStream before.
    final initialAuthUser =
        SwimAgentBasicFirebaseUser.fromFirebaseUser(
            FirebaseAuth.instance.currentUser);
    currentUser = initialAuthUser;
    _appStateNotifier.update(initialAuthUser);

    _authSwimmerSub =
        FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      final authUser =
          SwimAgentBasicFirebaseUser.fromFirebaseUser(firebaseUser);
      currentUser = authUser;
      _appStateNotifier.update(authUser);
      if (firebaseUser != null) {
        try {
          await firebaseUser.getIdToken();
        } catch (_) {}
        await refreshSwimmerAppState();
      } else {
        await FFAppState().clearSwimmerContext();
      }
    });

    Future.delayed(
        const Duration(milliseconds: 1000),
        () => safeSetState(() => _appStateNotifier.stopShowingSplashImage()));
  }

  @override
  void dispose() {
    _authSwimmerSub?.cancel();
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    final light = _lightTheme;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SwimAgentBasic',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        scaffoldBackgroundColor: light.primaryBackground,
        canvasColor: light.primaryBackground,
        primaryColor: light.primary,
        colorScheme: ColorScheme.light(
          primary: light.primary,
          onPrimary: light.primaryBtnText,
          secondary: light.secondary,
          onSecondary: light.primaryText,
          surface: light.secondaryBackground,
          onSurface: light.primaryText,
          error: light.error,
          onError: light.primaryBtnText,
          outline: light.lineColor,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
