class Message {
  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;

  Message({required this.id, required this.sender, required this.text, required this.timestamp});

  factory Message.fromMap(Map<String, dynamic> m) {
    return Message(
      id: m['id'] as String,
      sender: m['sender'] as String,
      text: m['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
    );
  }

  Map<String, dynamic> toMap({required String peer}) {
    return {
      'id': id,
      'peer': peer,
      'sender': sender,
      'text': text,
      'ts': timestamp.millisecondsSinceEpoch,
    };
  }
}
