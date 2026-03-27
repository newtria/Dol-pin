import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key, required this.targetName});
  final String targetName;

  static Future<Map<String, String>?> show(
      BuildContext context, String targetName) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => ReportDialog(targetName: targetName),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _reason;
  final _descController = TextEditingController();

  static List<(String, String)> _reasons(AppLocalizations l) => [
    ('scam', l.reasonScam),
    ('counterfeit', l.reasonCounterfeit),
    ('inappropriate', l.reasonInappropriate),
    ('other', l.reasonOther),
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l.reportTitle(widget.targetName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.selectReason,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _reasons(l).map((r) {
                  final (value, label) = r;
                  return GestureDetector(
                    onTap: () => setState(() => _reason = value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<String>(value: value),
                          const SizedBox(width: 8),
                          Text(label),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.additionalDetails,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: _reason != null
              ? () => Navigator.pop(context, {
                    'reason': _reason!,
                    'description': _descController.text,
                  })
              : null,
          child: Text(l.report),
        ),
      ],
    );
  }
}
