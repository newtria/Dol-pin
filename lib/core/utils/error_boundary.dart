import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';

/// Catches widget-level errors and shows a fallback UI.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({super.key, required this.child});
  final Widget child;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Material(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.somethingWentWrong ?? 'Something went wrong',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: Text(AppLocalizations.of(context)?.tryAgain ?? 'Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
