// -----------------------------------------------------------------------
// Filename: main.dart
// Original Author: Dan Grissom
// Creation Date: 5/18/2024
// Copyright: (c) 2024 CSC322
// Description: This file is the main entry point for the app and
//              initializes the app and the router.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Dart imports

// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// App relative file imports
import 'screens/general/screen_profile.dart';
import 'screens/general/screen_home.dart';
import 'widgets/navigation/widget_primary_scaffold.dart';
import 'screens/auth/screen_login_validation.dart';
import 'screens/settings/screen_profile_edit.dart';
import 'screens/settings/screen_settings.dart';
import 'util/file/util_file.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';
import 'providers/provider_user_profile.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

// Keep existing screens' imports of main.dart working during migration.
export 'providers/provider_user_profile.dart';
export 'providers/provider_auth.dart';

//////////////////////////////////////////////////////////////////////////
// MAIN entry point to start app.
//////////////////////////////////////////////////////////////////////////
Future<void> main() async {
  // Initialize widgets and firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the default options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check after Firebase is ready.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );

  // Initialize the app directory
  await UtilFile.init();

  // Riverpod creates and disposes its own container and providers.
  runApp(const ProviderScope(child: MyApp()));
}

//////////////////////////////////////////////////////////////////////////
// Main class which is the root of the app.
//////////////////////////////////////////////////////////////////////////
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

//////////////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////////////
class _MyAppState extends ConsumerState<MyApp> {
  // The "instance variables" managed in this state
  // NONE

  // Router
  final GoRouter _router = GoRouter(
    initialLocation: ScreenLoginValidation.routeName,
    routes: [
      GoRoute(path: ScreenLoginValidation.routeName, builder: (context, state) => const ScreenLoginValidation()),
      GoRoute(path: ScreenSettings.routeName, builder: (context, state) => ScreenSettings()),
      GoRoute(path: ScreenProfileEdit.routeName, builder: (context, state) => const ScreenProfileEdit()),
      GoRoute(
        path: WidgetPrimaryScaffold.routeName,
        builder: (BuildContext context, GoRouterState state) => const WidgetPrimaryScaffold(),
      ),
      GoRoute(path: ScreenHome.routeName, builder: (BuildContext context, GoRouterState state) => ScreenHome()),
      GoRoute(
        path: ScreenProfile.routeName,
        builder: (BuildContext context, GoRouterState state) => const ScreenProfile(),
      ),
    ],
  );

  //////////////////////////////////////////////////////////////////////////
  // Primary Flutter method overriden which describes the layout
  // and bindings for this widget.
  //////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(providerUserProfile.select((state) => state.profile.isDarkMode));

    return MaterialApp.router(
      routerConfig: _router,
      title: 'CSC 322 Starter Project',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
    );
  }
}
