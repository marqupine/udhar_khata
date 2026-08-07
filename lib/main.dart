import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mpin_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';
import 'services/udhar_repository.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp();
  } catch (e) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      debugPrint(
        'Firebase initialization warning: Ensure google-services.json or firebase_options.dart are configured.',
      );
    }
  }

  final firestoreService = FirestoreService();
  final storageService = await StorageService.init();
  final repository = UdharRepository(storageService, firestoreService);
  final authService = AuthService(firestoreService: firestoreService);
  final securityService = SecurityService(storageService.prefs);

  runApp(
    UdharKhataApp(
      repository: repository,
      authService: authService,
      securityService: securityService,
    ),
  );
}

class UdharKhataApp extends StatefulWidget {
  final UdharRepository repository;
  final AuthService authService;
  final SecurityService securityService;

  const UdharKhataApp({
    super.key,
    required this.repository,
    required this.authService,
    required this.securityService,
  });

  @override
  State<UdharKhataApp> createState() => _UdharKhataAppState();
}

class _UdharKhataAppState extends State<UdharKhataApp> {
  bool _isAppUnlocked = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder(
        stream: widget.authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.saffronPrimary,
                ),
              ),
            );
          }

          final user = snapshot.data;

          // 1. User not signed in -> Login Screen
          if (user == null) {
            _isAppUnlocked = false; // Reset lock status on logout
            return LoginScreen(authService: widget.authService);
          }

          // Ensure User Profile in Firestore is synced
          widget.authService.ensureUserSynced();

          // 2. User signed in, check MPIN/Biometrics Lock
          if (widget.securityService.hasMpin && !_isAppUnlocked) {
            return MpinScreen(
              securityService: widget.securityService,
              onUnlocked: () {
                setState(() {
                  _isAppUnlocked = true;
                });
              },
            );
          }

          // 3. User signed in & unlocked -> Dashboard
          return DashboardScreen(
            repository: widget.repository,
            authService: widget.authService,
            securityService: widget.securityService,
          );
        },
      ),
    );
  }
}
