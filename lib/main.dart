import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/udhar_repository.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  final repository = UdharRepository(storageService);

  runApp(UdharKhataApp(repository: repository));
}

class UdharKhataApp extends StatelessWidget {
  final UdharRepository repository;

  const UdharKhataApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Udhar Khata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: DashboardScreen(repository: repository),
    );
  }
}
