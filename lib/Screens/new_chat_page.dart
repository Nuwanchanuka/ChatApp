import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/settings.dart';

class NewChatPage extends StatefulWidget {
  final Chat? chat;
  final String? contactName;
  
  const NewChatPage({
    super.key, 
    this.chat,
    this.contactName,
  });

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isTyping = false;
  bool _chatReady = false;
  late Chat _currentChat;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool get _isEphemeralPeerChat =>
      _chatService.peerId != null && _currentChat.chatId == _chatService.peerId;

  Future<bool> _confirmExitAndMaybeDelete() async {
    // Only prompt for ephemeral QR/peer chats. Otherwise just leave.
  if (!_isEphemeralPeerChat) return true;

  // If this chat is already marked as extended, don't ask again
  final settings = SettingsService();
  final alreadyExtended = await settings.isChatExtended(_currentChat.chatId);
  if (alreadyExtended) return true;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection notice'),
        content: const Text(
          'This connection will be temporary and will only be extended by the consent of both parties.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'temp'),
            child: const Text('Keep temporary'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'extend'),
            child: const Text('Extend & save'),
          ),
        ],
      ),
    );

    if (choice == 'temp') {
      try {
        await _chatService.deleteChat(_currentChat.chatId);
      } catch (_) {}
      return true; // pop
    }

  if (choice == 'extend') {
      // Keep chat; optionally notify peer
      try {
        await _chatService.sendMessage(
          chatId: _currentChat.chatId,
          content: '🔒 I’d like to keep this chat. Do you agree?',
        );
    await settings.setChatExtended(_currentChat.chatId, true);
      } catch (_) {}
      return true; // pop without deleting
    }

    return false; // no selection
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await _initializeChat();
    if (!mounted) return;
    setState(() {
      _chatReady = true;
    });
    await _loadMessages();
    _listenToIncomingMessages();
    _listenToTyping();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  Future<void> _initializeChat() async {
    if (widget.chat != null) {
      _currentChat = widget.chat!;
    } else if (widget.contactName != null) {
      // Create new chat if only contact name is provided
      _currentChat = await _chatService.createOrGetChat(
        widget.contactName!,
        contactId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      );
    } else {
      // Default chat
      _currentChat = await _chatService.createOrGetChat(
        'New Chat',
        contactId: 'default_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  String _displayName() {
    final fromParam = (widget.contactName ?? '').trim();
    if (fromParam.isNotEmpty) return fromParam;
    final name = _chatReady ? _currentChat.name.trim() : '';
    return name.isNotEmpty ? name : 'Chat';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _listenToIncomingMessages() {
    _chatService.incomingStream.listen((_) {
      _loadMessages();
    });
  }

  void _listenToTyping() {
    _messageController.addListener(() {
      final currentText = _messageController.text;
      if (currentText.isNotEmpty && !_isTyping) {
        setState(() => _isTyping = true);
        // Send typing indicator (if needed)
      } else if (currentText.isEmpty && _isTyping) {
        setState(() => _isTyping = false);
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatMessages(_currentChat.chatId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        chatId: _currentChat.chatId,
        content: text,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _buildMessage(Message message, int index) {
    final isMe = message.senderId == _chatService.currentUserId;
    final isLastMessage = index == _messages.length - 1;
    final showTime = index == 0 || 
        _messages[index - 1].timestamp.difference(message.timestamp).inMinutes.abs() > 5;

    return Column(
      children: [
        if (showTime) _buildTimeStamp(message.timestamp),
        Container(
          margin: EdgeInsets.only(
            left: isMe ? 50 : 16,
            right: isMe ? 16 : 50,
            top: 4,
            bottom: isLastMessage ? 16 : 4,
          ),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe 
                  ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: isMe ? null : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStamp(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
  final titleName = _displayName();
    return WillPopScope(
  onWillPop: _confirmExitAndMaybeDelete,
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            final ok = await _confirmExitAndMaybeDelete();
            if (ok && mounted) Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
        titleName.isNotEmpty ? titleName[0].toUpperCase() : 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
          titleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _chatService.isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
  actions: const [],
      ),
  body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessage(_messages[index], index);
                          },
                        ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    ));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start your conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin chatting with ${_displayName()}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
  // Keep a fixed bottom padding; avoid adding viewInsets here because
  // the Scaffold already resizes for the keyboard. Adding it causes
  // the input to jump up toward the middle when typing.
  bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sending ? null : _sendMessage,
            ),
          ),
        ],
      ),
  ));
  }
}
