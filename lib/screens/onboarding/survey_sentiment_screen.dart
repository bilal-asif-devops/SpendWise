import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SurveySentimentScreen extends StatelessWidget {
  final String? selectedSentiment;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  const SurveySentimentScreen({
    super.key,
    required this.selectedSentiment,
    required this.onSelect,
    required this.onContinue,
  });

  static const List<Map<String, String>> options = [
    {
      'id': 'stressed',
      'emoji': '😫',
      'title': 'Stressed',
      'subtitle': 'I want to hide',
    },
    {
      'id': 'unsure',
      'emoji': '🤔',
      'title': 'Unsure',
      'subtitle': 'Not much direction',
    },
    {
      'id': 'stable',
      'emoji': '😊',
      'title': 'Stable',
      'subtitle': 'No fires to put out',
    },
    {
      'id': 'confident',
      'emoji': '💪',
      'title': 'Confident',
      'subtitle': 'Ready for my TED talk',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.33,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '1/3',
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
            'How do you feel about your finances today?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the option that describes you best.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Options List
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = options[index];
                final isSelected = selectedSentiment == item['id'];

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
                                  fontSize: 17,
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

          // Sticky Continue button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedSentiment != null
                        ? AppColors.accentGreen
                        : const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: selectedSentiment != null ? onContinue : null,
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
