import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/models/lock_entry.dart';
import 'core/models/blocked_domain.dart';
import 'core/models/quota_entry.dart';
import 'core/theme/jeda_theme.dart';
import 'core/services/storage_service.dart';
import 'features/onboarding/feature_walkthrough_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Register Adapters
  Hive.registerAdapter(LockEntryAdapter());
  Hive.registerAdapter(BlockedDomainAdapter());
  Hive.registerAdapter(QuotaEntryAdapter());

  // Initialize Storage Service
  final storageService = StorageService();
  await storageService.init();
  await storageService.cleanExpiredLocks();
  
  runApp(ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(storageService),
    ],
    child: JedaApp(storageService: storageService),
  ));
}

class JedaApp extends StatelessWidget {
  final StorageService storageService;

  const JedaApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeda',
      debugShowCheckedModeBanner: false,
      theme: JedaTheme.lightTheme,
      home: storageService.isOnboardingDone()
          ? const DashboardScreen()
          : const FeatureWalkthroughScreen(),
    );
  }
}
