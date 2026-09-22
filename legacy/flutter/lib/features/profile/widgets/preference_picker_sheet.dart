import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

typedef PreferenceOption = ({String code, String label});

class PreferencePickerSheet extends StatelessWidget {
  const PreferencePickerSheet({
    super.key,
    required this.options,
    required this.currentCode,
    required this.onSelected,
  });

  final List<PreferenceOption> options;
  final String currentCode;
  final Future<void> Function(String code) onSelected;

  static Future<void> show(
    BuildContext context, {
    required List<PreferenceOption> options,
    required String currentCode,
    required Future<void> Function(String code) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => PreferencePickerSheet(
        options: options,
        currentCode: currentCode,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: option.code == currentCode
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await onSelected(option.code);
              },
            ),
        ],
      ),
    );
  }
}
