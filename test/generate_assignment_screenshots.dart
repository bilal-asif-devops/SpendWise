import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/models/models.dart';
import 'package:spendwise/services/auth_sync_provider.dart';
import 'package:spendwise/services/finance_provider.dart';
import 'package:spendwise/services/local_auth_service.dart';
import 'package:spendwise/services/storage_service.dart';
import 'package:spendwise/theme/app_theme.dart';
import 'package:spendwise/screens/main_navigation.dart';
import 'package:spendwise/screens/onboarding/onboarding_flow_screen.dart';
import 'package:spendwise/screens/import_statement_screen.dart';

class InMemoryStorageService extends LocalStorageService {
  @override
  Future<Map<String, dynamic>?> loadVault() async => null;

  @override
  Future<bool> saveVault(Map<String, dynamic> vault) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory(r'C:\Users\Lenovo\Desktop\SpendWise_Flutter\assignment_screens');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  setUpAll(() async {
    // 1. Load Segoe UI as Roboto & sans-serif
    final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (fontFile.existsSync()) {
      final fontBytes = fontFile.readAsBytesSync();
      final fontLoader = FontLoader('Roboto');
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();

      final sansLoader = FontLoader('sans-serif');
      sansLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await sansLoader.load();
    }

    // 2. Load MaterialIcons
    final iconFile = File(r'C:\Users\Lenovo\Downloads\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
    if (iconFile.existsSync()) {
      final iconBytes = iconFile.readAsBytesSync();
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await iconLoader.load();
    }
  });

  FinanceProvider createSeededFinance() {
    final fp = FinanceProvider(
      storageService: InMemoryStorageService(),
      seedSampleData: false,
    );
    fp.startFreshGuest();
    fp.updateProfile(name: 'Bilal Ahmed', email: 'bilal@spendwise.pk');
    fp.toggleBiometrics(true);

    fp.addAccount(Account(
      id: 'acc_meezan',
      name: 'Meezan Bank',
      type: AccountType.debit,
      balance: 90000.0,
      currency: 'PKR',
      icon: '🏛️',
    ));
    fp.addAccount(Account(
      id: 'acc_easypaisa',
      name: 'Easypaisa',
      type: AccountType.cash,
      balance: 500000.0,
      currency: 'PKR',
      icon: '📱',
    ));
    fp.addAccount(Account(
      id: 'acc_scb_cc',
      name: 'Standard Chartered CC',
      type: AccountType.credit,
      balance: 45000.0,
      creditLimit: 250000.0,
      currency: 'PKR',
      icon: '💳',
    ));

    fp.addSubscription(
      name: 'Netflix 4K UHD',
      category: 'Entertainment',
      amount: 500.0,
      days: 30,
      accountId: 'acc_meezan',
    );
    fp.addSubscription(
      name: 'Spotify Premium',
      category: 'Entertainment',
      amount: 350.0,
      days: 14,
      accountId: 'acc_meezan',
    );

    fp.addBudget(Budget(
      id: 'b_food',
      name: 'Food & Drinks',
      category: 'Food & Drinks',
      targetAmount: 45000.0,
      spentAmount: 28500.0,
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      icon: '🍔',
    ));
    fp.addBudget(Budget(
      id: 'b_groceries',
      name: 'Groceries',
      category: 'Groceries',
      targetAmount: 60000.0,
      spentAmount: 34200.0,
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      icon: '🛒',
    ));
    fp.addBudget(Budget(
      id: 'b_shopping',
      name: 'Shopping & Retail',
      category: 'Shopping',
      targetAmount: 30000.0,
      spentAmount: 18000.0,
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      icon: '🛍️',
    ));
    fp.addBudget(Budget(
      id: 'b_rent',
      name: 'Rent & Housing',
      category: 'Rent & Housing',
      targetAmount: 85000.0,
      spentAmount: 85000.0,
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      icon: '🏡',
    ));

    final now = DateTime.now();
    fp.addExpense(
      title: 'Metro Cash & Carry',
      amount: 14200.0,
      category: 'Groceries',
      accountId: 'acc_meezan',
      date: now.subtract(const Duration(hours: 4)),
    );
    fp.addExpense(
      title: 'Fuel Shell Gas Station',
      amount: 6500.0,
      category: 'Transport',
      accountId: 'acc_meezan',
      date: now.subtract(const Duration(days: 1)),
    );
    fp.addExpense(
      title: 'Espresso Lounge Dinner',
      amount: 4800.0,
      category: 'Food & Drinks',
      accountId: 'acc_easypaisa',
      date: now.subtract(const Duration(days: 2)),
    );
    fp.addExpense(
      title: 'Electricity Bill LESCO',
      amount: 18500.0,
      category: 'Utilities',
      accountId: 'acc_meezan',
      date: now.subtract(const Duration(days: 4)),
    );

    return fp;
  }

  testWidgets('Generate all 7 live SpendWise assignment screens', (tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed')) return;
      FlutterError.dumpErrorToConsole(details);
    };

    final fp = createSeededFinance();
    final localAuth = LocalAuthService();
    final auth = AuthSyncProvider(
      authService: localAuth,
      cloudSyncService: localAuth,
      storageService: InMemoryStorageService(),
      financeProvider: fp,
    );

    const double screenWidth = 430.0;
    const double screenHeight = 932.0;

    tester.view.physicalSize = const Size(860, 1864);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      localAuth.dispose();
      auth.dispose();
    });

    final repaintKey = GlobalKey();

    Future<void> saveCurrent(String filename) async {
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${outDir.path}/$filename');
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
        print('Captured ${file.path} (${file.lengthSync()} bytes)');
      });
    }

    // --- SCREEN 1: Onboarding Carousel ---
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: fp),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: auth),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: repaintKey,
              child: const SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: OnboardingFlowScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveCurrent('screen_1_onboarding.png');

    // --- MAIN NAVIGATION SCREENS ---
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: fp),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: auth),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: repaintKey,
              child: const SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: MainNavigationScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // --- SCREEN 2: Home / Timeline Dashboard ---
    await saveCurrent('screen_2_home.png');

    // --- SCREEN 4: Wallets & Credit Cards (Tab 1) ---
    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();
    await saveCurrent('screen_4_wallets.png');

    // --- SCREEN 3: Budgets Dashboard (Tab 2) ---
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    await saveCurrent('screen_3_budgets.png');

    // --- SCREEN 6: Activity & Insights (Tab 3) ---
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await saveCurrent('screen_6_activity.png');

    // --- SCREEN 7: More / Settings (Tab 4) ---
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await saveCurrent('screen_7_more.png');

    // --- SCREEN 5: Bank Statement Importer ---
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>.value(value: fp),
          ChangeNotifierProvider<AuthSyncProvider>.value(value: auth),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: repaintKey,
              child: const SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: ImportStatementScreen(preselectedAccountId: 'acc_meezan'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (find.byKey(const Key('sample_meezan_chip')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('sample_meezan_chip')));
      await tester.pumpAndSettle();
    }
    await saveCurrent('screen_5_import.png');
  });
}
