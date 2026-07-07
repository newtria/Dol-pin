class ChatSummaryModel {
  const ChatSummaryModel({
    required this.roomId,
    required this.partnerId,
    this.partnerNickname,
    this.partnerImage,
    required this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  final String roomId;
  final String partnerId;
  final String? partnerNickname;
  final String? partnerImage;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory ChatSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawLastMessageAt = json['last_message_at'];
    return ChatSummaryModel(
      roomId: _requiredString(json, 'room_id'),
      partnerId: _requiredString(json, 'partner_id'),
      partnerNickname: _optionalNonEmptyString(json['partner_nickname']),
      partnerImage: _optionalNonEmptyString(json['partner_image']),
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageAt: rawLastMessageAt == null
          ? null
          : DateTime.tryParse(rawLastMessageAt.toString()),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString();
    if (value == null || value.trim().isEmpty) {
      throw FormatException('Missing chat summary field', key);
    }
    return value;
  }

  static String? _optionalNonEmptyString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
