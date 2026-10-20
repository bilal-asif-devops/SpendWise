import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SurveyHabitsScreen extends StatelessWidget {
  final String? selectedHabit;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const SurveyHabitsScreen({
    super.key,
    required this.selectedHabit,
    required this.onSelect,
    required this.onContinue,
    required this.onBack,
  });

  static const List<Map<String, String>> habits = [
    {
      'id': 'pro',
      'emoji': '🧠',
      'title': "I'm a habit pro",
      'subtitle': 'Discipline is second nature',
    },
    {
      'id': 'strong_start',
      'emoji': '😅',
      'title': 'I start strong but fall off',
      'subtitle': 'Need consistent momentum',
    },
    {
      'id': 'reminders_help',
      'emoji': '🔔',
      'title': 'Reminders really help me',
      'subtitle': 'Gentle nudges keep me on track',
    },
    {
      'id': 'beginner',
      'emoji': '🤔',
      'title': 'New habits? What are those?',
      'subtitle': 'Starting completely fresh',
    },
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
                    value: 1.0,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '3/3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Question Headline
          const Text(
            'How easy is it for you to stick to new habits?',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the answer that feels most accurate.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Habit Cards
          Expanded(
            child: ListView.separated(
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = habits[index];
                final isSelected = selectedHabit == item['id'];

                return InkWell(
                  onTap: () => onSelect(item['id']!),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGreen.withValues(alpha: 0.08)
                          : AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGreen
                            : AppColors.borderLight,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          item['emoji']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.primaryNavy
                                      : AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.accentGreen,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Continue Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedHabit != null
                        ? AppColors.accentGreen
                        : const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: selectedHabit != null ? onContinue : null,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
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
