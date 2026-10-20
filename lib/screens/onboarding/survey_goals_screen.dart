import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SurveyGoalsScreen extends StatelessWidget {
  final Set<String> selectedGoals;
  final ValueChanged<String> onToggleGoal;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const SurveyGoalsScreen({
    super.key,
    required this.selectedGoals,
    required this.onToggleGoal,
    required this.onContinue,
    required this.onBack,
  });

  static const List<Map<String, String>> goals = [
    {'id': 'emergency', 'emoji': '🚨', 'title': 'Emergency fund'},
    {'id': 'retirement', 'emoji': '🏖️', 'title': 'Retirement'},
    {'id': 'investments', 'emoji': '📈', 'title': 'Investments'},
    {'id': 'home', 'emoji': '🏡', 'title': 'New home'},
    {'id': 'car', 'emoji': '🚗', 'title': 'New car'},
    {'id': 'vacation', 'emoji': '🌴', 'title': 'Vacation'},
    {'id': 'other', 'emoji': '🧩', 'title': 'Other'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Back button and progress
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.66,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '2/3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Question Headline
          const Text(
            'Are you saving, or planning to, for any of these?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select all that apply to you.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),

          // Goals Multi-Select List
          Expanded(
            child: ListView.separated(
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = goals[index];
                final isSelected = selectedGoals.contains(item['id']);

                return InkWell(
                  onTap: () => onToggleGoal(item['id']!),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGreen.withValues(alpha: 0.08)
                          : AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGreen
                            : AppColors.borderLight,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          item['emoji']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item['title']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primaryNavy
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.accentGreen
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentGreen
                                  : const Color(0xFF94A3B8),
                              width: 1.8,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Continue button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedGoals.isNotEmpty
                        ? AppColors.accentGreen
                        : const Color(0xFF94A3B8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onContinue,
                  child: Text(
                    selectedGoals.isNotEmpty ? 'Continue' : 'Skip this step',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
