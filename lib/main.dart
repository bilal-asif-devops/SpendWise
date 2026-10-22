import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/auth_sync_provider.dart';
import 'services/finance_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(const SpendWiseApp());
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProxyProvider<FinanceProvider, AuthSyncProvider>(
          create: (ctx) => AuthSyncProvider.createDefault(
            financeProvider: ctx.read<FinanceProvider>(),
          ),
          update: (ctx, finance, previous) =>
              previous ??
              AuthSyncProvider.createDefault(
                financeProvider: finance,
              ),
        ),
      ],
      child: Consumer<FinanceProvider>(
        builder: (context, finance, child) {
          return MaterialApp(
            title: 'SpendWise',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: finance.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
