class Chat {
  final int? id;
  final String chatId;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? avatar;
  final int unreadCount;
  final DateTime createdAt;
  final String userId; // The logged-in user's ID

  Chat({
    this.id,
    required this.chatId,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    this.avatar,
    this.unreadCount = 0,
    required this.createdAt,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'name': name,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.millisecondsSinceEpoch,
      'avatar': avatar,
      'unread_count': unreadCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'user_id': userId,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id']?.toInt(),
      chatId: map['chat_id'] ?? '',
      name: map['name'] ?? '',
      lastMessage: map['last_message'],
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'])
          : null,
      avatar: map['avatar'],
      unreadCount: map['unread_count']?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      userId: map['user_id'] ?? '',
    );
  }

  Chat copyWith({
    int? id,
    String? chatId,
    String? name,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? avatar,
    int? unreadCount,
    DateTime? createdAt,
    String? userId,
  }) {
    return Chat(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      avatar: avatar ?? this.avatar,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}
