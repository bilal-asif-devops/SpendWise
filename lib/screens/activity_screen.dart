import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_provider.dart';
import '../theme/app_theme.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Smart insights",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Today
              const Text(
                "Today",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 12),

              // Emerald Financial Health Card matching unnamed (5).webp
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "FINANCIAL HEALTH",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Your financial health is getting better!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Last month you earned 254 ${finance.currency} more than you spent which means your reserve raised to 6 704 ${finance.currency}.",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.35),
                    ),
                    const SizedBox(height: 16),

                    // Smooth White Spline Curve
                    SizedBox(
                      height: 65,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 4,
                          minY: 0,
                          maxY: 5,
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 1.2),
                                FlSpot(1, 2.0),
                                FlSpot(2, 2.2),
                                FlSpot(3, 3.8),
                                FlSpot(4, 4.5),
                              ],
                              isCurved: true,
                              color: Colors.white,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Aug",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10)),
                        Text("Oct",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10)),
                        Text("Dec",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section: Yesterday
              const Text(
                "Yesterday",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 12),

              // Amber Insight Card matching Spendee
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text("🍽️", style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "INSIGHT",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Good job!",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Yesterday you spent 0 ${finance.currency} on Food & Drinks which is 50 ${finance.currency} below your average.",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Amazing Fact Card matching Spendee
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "AMAZING FACT",
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "This year, you've already spent ${finance.currency}1,284 on Food & Drinks",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "You could buy approx 1 950 McNuggets for that value.",
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text("🍗", style: TextStyle(fontSize: 34)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Money Overview (Donut Breakdown from unnamed (2).webp)
              const Text(
                "Money overview (Categories)",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 52,
                          sections: [
                            PieChartSectionData(
                              color: const Color(0xFFF59E0B),
                              value: 28,
                              title: "28%",
                              radius: 36,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFF10B981),
                              value: 24,
                              title: "24%",
                              radius: 36,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFEF4444),
                              value: 18,
                              title: "18%",
                              radius: 36,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFF3B82F6),
                              value: 14,
                              title: "14%",
                              radius: 36,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: const Color(0xFFEC4899),
                              value: 16,
                              title: "16%",
                              radius: 36,
                              titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryRow(
                        "Food & Drink",
                        "24 transactions",
                        "-419,64 ${finance.currency}",
                        const Color(0xFFF59E0B),
                        "🍔"),
                    _buildCategoryRow(
                        "Rent & Housing",
                        "2 transactions",
                        "-360,00 ${finance.currency}",
                        const Color(0xFF10B981),
                        "🏠"),
                    _buildCategoryRow(
                        "Travel",
                        "13 transactions",
                        "-434,00 ${finance.currency}",
                        const Color(0xFFEF4444),
                        "✈️"),
                    _buildCategoryRow(
                        "Transport & Transit",
                        "8 transactions",
                        "-125,00 ${finance.currency}",
                        const Color(0xFF3B82F6),
                        "🚗"),
                    _buildCategoryRow(
                        "Personal",
                        "5 transactions",
                        "-239,76 ${finance.currency}",
                        const Color(0xFFEC4899),
                        "👤"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(
      String title, String count, String amount, Color color, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(count,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(amount,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
