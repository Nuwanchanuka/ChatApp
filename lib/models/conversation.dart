class Conversation {
  final String peer;
  final String lastSender;
  final String lastText;
  final DateTime lastTs;
  final int unread;

  Conversation({
    required this.peer,
    required this.lastSender,
    required this.lastText,
    required this.lastTs,
    this.unread = 0,
  });
}
