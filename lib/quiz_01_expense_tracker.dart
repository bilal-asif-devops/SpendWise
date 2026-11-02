// ==============================================================================
// UNIVERSITY OF ENGINEERING AND TECHNOLOGY (UET), TAXILA
// DEPARTMENT OF SOFTWARE ENGINEERING
// Course: Mobile Application Development (MAD) | Class: 23-SE (Alpha)
// Instructor: Dr. Kanwal Yousaf
// Student Name: Muhammad Bilal (Bilal Asif) | Roll No: 23-SE-XXX
// Quiz 01 — Question #2: Expense Tracker Summary (Alpha)
// ==============================================================================

import 'package:flutter/material.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

/// Root Application Widget configuring the Material Design theme.
class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker Summary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==============================================================================
// SCREEN 1: HOME SCREEN (Capture User Details & Monthly Income)
// ==============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Hardcoded or dynamically customizable student/user name
  final String _userName = 'Muhammad Bilal';

  // Controller capturing the user's monthly income
  final TextEditingController _incomeController =
      TextEditingController(text: '75000');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  void _navigateToAddExpenses() {
    if (_formKey.currentState?.validate() ?? false) {
      final double income =
          double.tryParse(_incomeController.text.trim()) ?? 0.0;
      // Navigate to Screen 2 and pass the user's name and monthly income
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseScreen(
            userName: _userName,
            monthlyIncome: income,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker — Alpha'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome header card with Icon and Text value widgets
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFF0D9488),
                        child:
                            Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Welcome, $_userName!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Class: 23-SE (Alpha) • UET Taxila',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Income input section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Monthly Income (PKR)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _incomeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.account_balance_wallet_outlined),
                          prefixText: 'PKR ',
                          hintText: 'Enter monthly income',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter monthly income';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Action button navigating to Screen 2
              ElevatedButton.icon(
                onPressed: _navigateToAddExpenses,
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('Add Expenses',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// SCREEN 2: EXPENSE SCREEN (Category Expenses Entry & Remaining Balance)
// ==============================================================================
class ExpenseScreen extends StatefulWidget {
  final String userName;
  final double monthlyIncome;

  const ExpenseScreen({
    super.key,
    required this.userName,
    required this.monthlyIncome,
  });

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // Required standard expense categories specified in Quiz instructions
  final List<String> _categories = [
    'Grocery',
    'Electricity & Gas Bill',
    'Internet',
    'Education',
    'Entertainment',
    'Savings',
    'Travel',
  ];

  // Map storing text editing controllers for each category
  final Map<String, TextEditingController> _controllers = {};

  double _totalExpenses = 0.0;
  double _remainingBalance = 0.0;
  bool _hasCalculated = false;

  @override
  void initState() {
    super.initState();
    // Initialize controller for each category with sample default or empty string
    final defaultValues = {
      'Grocery': '15000',
      'Electricity & Gas Bill': '12000',
      'Internet': '3500',
      'Education': '18000',
      'Entertainment': '5000',
      'Savings': '10000',
      'Travel': '4500',
    };
    for (final category in _categories) {
      _controllers[category] =
          TextEditingController(text: defaultValues[category] ?? '0');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateExpenses() {
    double total = 0.0;
    for (final controller in _controllers.values) {
      final value = double.tryParse(controller.text.trim()) ?? 0.0;
      total += value;
    }

    setState(() {
      _totalExpenses = total;
      _remainingBalance = widget.monthlyIncome - total;
      _hasCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSaved = _remainingBalance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses for ${widget.userName}'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Income overview card (non-editable display)
            Card(
              color: const Color(0xFFF0FDFA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF99F6E4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on, color: Color(0xFF0D9488)),
                        SizedBox(width: 8),
                        Text(
                          'Monthly Income:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      'PKR ${widget.monthlyIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Expense Categories Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'Expense Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            // List of category rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            category,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _controllers[category],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              prefixText: 'PKR ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _calculateExpenses,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculate Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic result display card
            if (_hasCalculated)
              Card(
                elevation: 3,
                color:
                    isSaved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isSaved
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFFFCA5A5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Expenses:',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(
                            'PKR ${_totalExpenses.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSaved
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: isSaved
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isSaved
                                  ? 'You saved PKR ${_remainingBalance.toStringAsFixed(0)} this month!'
                                  : 'You overspent by PKR ${(-_remainingBalance).toStringAsFixed(0)} this month.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSaved
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
