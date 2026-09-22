import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';

/// Shares [message] via the platform share sheet.
/// Falls back to copying [url] to the clipboard with a snackbar.
Future<void> shareWithFallback(
  BuildContext context, {
  required String url,
  required String message,
}) async {
  try {
    await Share.share(message);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.linkCopied)),
      );
    }
  }
}
