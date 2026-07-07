import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/share_helper.dart';
import '../../../data/models/concert_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/dolpin_card.dart';

class ConcertCard extends StatelessWidget {
  const ConcertCard({super.key, required this.concert, this.onTap});

  final ConcertModel concert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DolpinCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: concert.posterUrl != null
                  ? CachedImage(imageUrl: concert.posterUrl!)
                  : Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(
                        Icons.music_note,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            concert.artist,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            concert.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _ShareButton(concert: concert),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.concertDate(concert.concertDate),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${concert.venue}, ${concert.city}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.concert});
  final ConcertModel concert;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
        tooltip: l.share,
        onPressed: () {
          final url = 'https://dolpin.app/concert/${concert.id}';
          final message = '${l.shareConcert(concert.title)}\n$url';
          shareWithFallback(context, url: url, message: message);
        },
      ),
    );
  }
}
