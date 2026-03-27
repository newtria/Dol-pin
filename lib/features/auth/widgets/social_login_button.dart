import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

enum SocialProvider { apple, google }

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  final SocialProvider provider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, bgColor) = switch (provider) {
      SocialProvider.apple => (
          Icons.apple,
          Colors.white,
        ),
      SocialProvider.google => (
          Icons.g_mobiledata,
          AppColors.surfaceLight,
        ),
    };

    final label = switch (provider) {
      SocialProvider.apple => AppLocalizations.of(context)!.continueWithApple,
      SocialProvider.google => AppLocalizations.of(context)!.continueWithGoogle,
    };

    final textColor = switch (provider) {
      SocialProvider.apple => Colors.black,
      SocialProvider.google => AppColors.textPrimary,
    };

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
