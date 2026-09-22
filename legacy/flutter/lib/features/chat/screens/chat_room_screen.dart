import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../shared/dialogs/confirm_dialog.dart';
import '../../../shared/dialogs/report_dialog.dart';
import '../application/chat_room_controller.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.roomId,
  });

  final String otherUserId;
  final String otherUserName;
  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) return;

    final submittedText = _messageController.text;
    final text = submittedText.trim();
    if (text.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSending = true);

    final result = await ref
        .read(chatRoomControllerProvider)
        .sendMessage(
          roomId: widget.roomId,
          senderId: userId,
          receiverId: widget.otherUserId,
          text: text,
        );

    if (!mounted) return;
    setState(() => _isSending = false);
    result.when(
      success: (_) {
        if (_messageController.text == submittedText) {
          _messageController.clear();
        }
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.sendFailed}: ${f.message}',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUserName)),
        body: Center(child: Text(l.notLoggedIn)),
      );
    }
    if (widget.roomId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUserName)),
        body: Center(child: Text(l.couldNotLoadMessages)),
      );
    }

    final messagesAsync = ref.watch(chatRoomMessagesProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, userId),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'report', child: Text(l.report)),
              PopupMenuItem(value: 'block', child: Text(l.blockUser)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.startChatting,
                        style: const TextStyle(color: AppColors.textHint),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    return MessageBubble(
                      message: msg.message,
                      isMine: msg.senderId == userId,
                      timestamp: msg.createdAt ?? DateTime.now(),
                      translatedMessage: msg.translatedMessage,
                      imageUrl: msg.imageUrl,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  l.errorLoadingMessages,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: l.messageHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isSending ? null : _send,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String value, String userId) async {
    final l = AppLocalizations.of(context)!;

    if (value == 'report') {
      final result = await ReportDialog.show(context, widget.otherUserName);
      if (result != null && mounted) {
        final res = await ref
            .read(chatRoomControllerProvider)
            .reportUser(
              reporterId: userId,
              reportedUserId: widget.otherUserId,
              reason: result['reason']!,
              description: result['description'],
            );
        if (!mounted) return;
        res.when(
          success: (_) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.reportSubmitted))),
          failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l.reportFailed}: ${f.message}')),
          ),
        );
      }
    } else if (value == 'block') {
      final confirmed = await ConfirmDialog.show(
        context,
        title: l.blockUser,
        message: '${widget.otherUserName}?',
        confirmLabel: l.blockUser,
        isDestructive: true,
      );
      if (confirmed && mounted) {
        final res = await ref
            .read(chatRoomControllerProvider)
            .blockUser(blockerId: userId, blockedId: widget.otherUserId);
        if (!mounted) return;
        res.when(
          success: (_) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.userBlocked)));
            Navigator.of(context).pop();
          },
          failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l.userBlockFailed}: ${f.message}')),
          ),
        );
      }
    }
  }
}
