import 'package:flutter/material.dart';
import 'package:chatapp/services/chat_service.dart';
import 'package:chatapp/services/db.dart';
import '../models/message.dart';
import 'package:chatapp/services/settings.dart';

class ChatPage extends StatefulWidget {
  final String peer;
  const ChatPage({super.key, this.peer = 'peer'});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Message> _messages = [];
  late final String _me;
  bool _canSend = false;

  Future<void> _load() async {
    var rows = await DBService().getMessages(widget.peer);
    if (rows.isEmpty) {
      // Seed a few demo messages when history is empty
      final now = DateTime.now();
      final samples = [
        {'sender': 'Alice', 'text': 'Hey! Welcome to ChatApp 👋', 'ts': now.subtract(const Duration(minutes: 5))},
        {'sender': _me, 'text': 'Hi Alice! Testing the app.', 'ts': now.subtract(const Duration(minutes: 4))},
        {'sender': 'Alice', 'text': 'Looks good. Messages persist locally.', 'ts': now.subtract(const Duration(minutes: 3))},
        {'sender': _me, 'text': 'QR pairing works too.', 'ts': now.subtract(const Duration(minutes: 2))},
        {'sender': 'Alice', 'text': 'Great! Let\'s ship it.', 'ts': now.subtract(const Duration(minutes: 1))},
      ];
      var i = 0;
      for (final s in samples) {
        await DBService().insertMessage(
          peer: widget.peer,
          id: 'demo-${now.millisecondsSinceEpoch}-${i++}',
          sender: s['sender'] as String,
          text: s['text'] as String,
          ts: s['ts'] as DateTime,
        );
      }
      rows = await DBService().getMessages(widget.peer);
    }
    setState(() => _messages = rows);
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
  _me = SettingsService().username ?? 'me';
    _load();
  _canSend = ChatService().isConnected; // reflect current state immediately
  ChatService().incomingStream.listen((_) => _load());
    ChatService().connectionStream.listen((state) {
      setState(() {
        _canSend = ChatService().isConnected;
      });
      if (!mounted) return;
      if (state == 'connected') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected to peer')));
      } else if (state == 'disconnected') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected')));
      } else if (state.startsWith('error:')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error: ${state.substring(6)}')));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final mine = m.sender == _me;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: mine ? Colors.teal.shade200 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? 'You' : m.sender,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.text,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.timestamp.toLocal().toString().substring(0, 16),
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _canSend ? _send : null,
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!ChatService().isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not connected. Pair devices first.')));
      }
      return;
    }
    _controller.clear();
    try {
      await ChatService().send(_me, text);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
  }
}
