import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_view.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final userAsync = ref.watch(currentUserProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.messages,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null) return const _EmptyChatState();
                return _ChatList(userId: user.id);
              },
              loading: () => const LoadingIndicator(),
              error: (_, _) => const _EmptyChatState(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListAsync = ref.watch(chatListProvider(userId));

    return chatListAsync.when(
      data: (chats) {
        if (chats.isEmpty) return const _EmptyChatState();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chatListProvider(userId)),
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ChatListTile(
                nickname: chat['partner_nickname'] ?? 'User',
                profileImage: chat['partner_image'] as String?,
                lastMessage: chat['last_message'] ?? '',
                lastMessageAt: DateTime.tryParse(
                        chat['last_message_at']?.toString() ?? '') ??
                    DateTime.now(),
                unreadCount: (chat['unread_count'] as num?)?.toInt() ?? 0,
                onTap: () => context.pushNamed(
                  'chatRoom',
                  pathParameters: {'userId': chat['partner_id']},
                  queryParameters: {
                    'name': chat['partner_nickname'] ?? 'User'
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(
        message: AppLocalizations.of(context)!.couldNotLoadMessages,
        onRetry: () => ref.invalidate(chatListProvider(userId)),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l.noMessagesYet,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.startConversation,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.nickname,
    this.profileImage,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.onTap,
  });

  final String nickname;
  final String? profileImage;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceLight,
        backgroundImage: profileImage != null
            ? CachedNetworkImageProvider(profileImage!)
            : null,
        child: profileImage == null
            ? const Icon(Icons.person, color: AppColors.textHint)
            : null,
      ),
      title: Text(
        nickname,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unreadCount > 0
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormatter.relative(lastMessageAt, l),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
