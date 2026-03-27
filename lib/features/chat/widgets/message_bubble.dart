import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cached_image.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.timestamp,
    this.translatedMessage,
    this.imageUrl,
  });

  final String? message;
  final bool isMine;
  final DateTime timestamp;
  final String? translatedMessage;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMine)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                DateFormatter.relative(timestamp, AppLocalizations.of(context)!),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null) ...[
                    CachedImage(
                      imageUrl: imageUrl!,
                      width: 200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    if (message != null) const SizedBox(height: 6),
                  ],
                  if (message != null)
                    Text(
                      message!,
                      style: TextStyle(
                        color: isMine ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  if (translatedMessage != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              translatedMessage!,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                DateFormatter.relative(timestamp, AppLocalizations.of(context)!),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
