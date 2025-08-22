import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'db.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'database_service.dart';
import 'settings.dart';
import '../utils/logger.dart';

class ChatService {
  static final ChatService _i = ChatService._internal();
  factory ChatService() => _i;
  ChatService._internal();

  HttpServer? _server;
  WebSocket? _socket;
  String? peerId;
  final _uuid = const Uuid();
  final _incoming = StreamController<void>.broadcast();
  final _connection = StreamController<String>.broadcast();
  
  // New database service integration
  final DatabaseService _db = DatabaseService();

  Stream<void> get incomingStream => _incoming.stream;
  Stream<String> get connectionStream => _connection.stream;

  bool get isConnected => _socket != null;
  
  String get currentUserId => SettingsService().username ?? 'anonymous';

  Future<String?> _localIpv4() async {
    final nics = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final nic in nics) {
      for (final addr in nic.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  Future<String?> get serverWsUrl async {
    if (_server == null) return null;
    final ip = await _localIpv4();
    return ip == null ? null : 'ws://$ip:${_server!.port}/ws';
  }

  Future<String> startHost() async {
    try {
      AppLogger.connection('Starting host server...');
      // Bind on all interfaces so peers on same Wi-Fi can connect
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      AppLogger.connection('Server bound to port ${_server!.port}');
      
    _server!.listen((HttpRequest req) async {
        if (req.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
      final remoteIp = req.connectionInfo?.remoteAddress.address;
      AppLogger.connection('WebSocket upgrade request from $remoteIp');
      
      final ws = await WebSocketTransformer.upgrade(req);
          _socket = ws;
    _connection.add('connected');
      peerId = remoteIp ?? peerId ?? 'peer';
      AppLogger.connection('Connected to peer: $peerId');
      
          ws.listen((data) async {
            try {
              final m = jsonDecode(data as String) as Map<String, dynamic>;
              AppLogger.connection('Received message from $peerId');
              
              await DBService().insertMessage(
                peer: peerId!,
                id: m['id'] as String,
                sender: m['sender'] as String,
                text: m['text'] as String,
                ts: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
              );
              
              // Save to new database
              await _saveMessageToNewDb(
                chatId: peerId!,
                messageId: m['id'] as String,
                senderId: 'peer',
                senderName: m['sender'] as String,
                content: m['text'] as String,
                timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
              );
              
              _incoming.add(null);
            } catch (e) {
              AppLogger.error('Error processing received message', error: e);
            }
          }, onDone: () {
            _socket = null;
            _connection.add('disconnected');
            AppLogger.connection('WebSocket connection closed');
          }, onError: (e) {
            _socket = null;
            _connection.add('error:$e');
            AppLogger.error('WebSocket error', error: e);
          });
        } else {
          req.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
      
      final url = await serverWsUrl;
      if (url == null) {
        AppLogger.error('Could not determine local IP');
        throw Exception('Could not determine local IP');
      }
      
      AppLogger.connection('Server started at: $url');
      return url;
    } catch (e) {
      AppLogger.error('Failed to start host server', error: e);
      rethrow;
    }
  }

  Future<void> connectTo(String wsUrl, {String? peer}) async {
    try {
      AppLogger.connection('Attempting to connect to: $wsUrl');
      peerId = peer ?? Uri.parse(wsUrl).host;
      
    _socket = await WebSocket.connect(wsUrl);
    _connection.add('connected');
    AppLogger.connection('Successfully connected to peer: $peerId');
    
    _socket!.listen((data) async {
        try {
          final m = jsonDecode(data as String) as Map<String, dynamic>;
          AppLogger.connection('Received message from $peerId');
          
          await DBService().insertMessage(
            peer: peerId!,
            id: m['id'] as String,
            sender: m['sender'] as String,
            text: m['text'] as String,
            ts: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
          );
          
          // Save to new database
          await _saveMessageToNewDb(
            chatId: peerId!,
            messageId: m['id'] as String,
            senderId: 'peer',
            senderName: m['sender'] as String,
            content: m['text'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
          );
          
      _incoming.add(null);
        } catch (e) {
          AppLogger.error('Error processing received message', error: e);
        }
      }, onDone: () {
        _socket = null;
        _connection.add('disconnected');
        AppLogger.connection('Connection to $peerId closed');
      }, onError: (e) {
        _socket = null;
        _connection.add('error:$e');
        AppLogger.error('Connection error with $peerId', error: e);
      });
    } catch (e) {
      AppLogger.error('Failed to connect to $wsUrl', error: e);
      _connection.add('error:$e');
      rethrow;
    }
  }

  Future<void> send(String myName, String text) async {
    if (_socket == null || peerId == null) return;
    final msg = {
      'id': _uuid.v4(),
      'sender': myName,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _socket!.add(jsonEncode(msg));
    
    // Save to both old and new database
    await DBService().insertMessage(
      peer: peerId!,
      id: msg['id'] as String,
      sender: myName,
      text: text,
      ts: DateTime.now(),
    );
    
    // Save to new SQLite database
    await _saveMessageToNewDb(
      chatId: peerId!,
      messageId: msg['id'] as String,
      senderId: currentUserId,
      senderName: myName,
      content: text,
      timestamp: DateTime.now(),
    );
  }

  // New database methods
  Future<Chat> createOrGetChat(String contactName, {String? contactId}) async {
    final userId = currentUserId;
    final chatId = contactId ?? _uuid.v4();
    
    // Check if chat already exists
    Chat? existingChat = await _db.getChat(chatId, userId);
    if (existingChat != null) {
      return existingChat;
    }

    // Create new chat
    final chat = Chat(
      chatId: chatId,
      name: contactName,
      createdAt: DateTime.now(),
      userId: userId,
    );

    await _db.insertChat(chat);
    return chat;
  }

  Future<List<Chat>> getUserChats() async {
    return await _db.getChats(currentUserId);
  }

  Future<Chat?> getChat(String chatId) async {
    return await _db.getChat(chatId, currentUserId);
  }

  Future<void> deleteChat(String chatId) async {
    await _db.deleteChat(chatId, currentUserId);
  }

  Future<Message> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final userId = currentUserId;
    final userSettings = SettingsService();
    
    final message = Message(
      messageId: _uuid.v4(),
      chatId: chatId,
      senderId: userId,
      senderName: userSettings.username ?? 'You',
      content: content,
      type: type,
      timestamp: DateTime.now(),
      userId: userId,
    );

    await _db.insertMessage(message);
    
    // Send via WebSocket if connected
    if (_socket != null && peerId == chatId) {
      final msg = {
        'id': message.messageId,
        'sender': message.senderName,
        'text': content,
        'ts': message.timestamp.millisecondsSinceEpoch,
      };
      _socket!.add(jsonEncode(msg));
    }
    
    return message;
  }

  Future<Message> receiveMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final userId = currentUserId;
    
    final message = Message(
      messageId: _uuid.v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      userId: userId,
    );

    await _db.insertMessage(message);
    
    // Update unread count
    final chat = await _db.getChat(chatId, userId);
    if (chat != null) {
      final updatedChat = chat.copyWith(
        unreadCount: chat.unreadCount + 1,
        lastMessage: content,
        lastMessageTime: DateTime.now(),
      );
      await _db.updateChat(updatedChat);
    }

    _incoming.add(null); // Notify listeners
    return message;
  }

  Future<List<Message>> getChatMessages(String chatId, {int limit = 50, int offset = 0}) async {
    return await _db.getMessages(chatId, currentUserId, limit: limit, offset: offset);
  }

  Future<void> markChatAsRead(String chatId) async {
    await _db.markMessagesAsRead(chatId, currentUserId);
  }

  Future<int> getUnreadCount(String chatId) async {
    return await _db.getUnreadMessageCount(chatId, currentUserId);
  }

  Future<List<Message>> searchMessages(String query) async {
    return await _db.searchMessages(query, currentUserId);
  }

  Future<void> _saveMessageToNewDb({
    required String chatId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String content,
    required DateTime timestamp,
  }) async {
    final message = Message(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: timestamp,
      userId: currentUserId,
    );
    
    await _db.insertMessage(message);
    
    // Create or update chat
    Chat? chat = await _db.getChat(chatId, currentUserId);
    if (chat == null) {
      chat = Chat(
        chatId: chatId,
        name: senderName,
        createdAt: timestamp,
        userId: currentUserId,
        lastMessage: content,
        lastMessageTime: timestamp,
      );
      await _db.insertChat(chat);
    }
  }

  // Generate sample chats for demo
  Future<void> createSampleChats() async {
    final sampleContacts = [
      {'name': 'John Doe', 'lastMessage': 'Hey, how are you?'},
      {'name': 'Jane Smith', 'lastMessage': 'See you tomorrow!'},
      {'name': 'Bob Wilson', 'lastMessage': 'Thanks for the help'},
      {'name': 'Alice Johnson', 'lastMessage': 'Good morning! ☀️'},
    ];

    for (var contact in sampleContacts) {
      final chat = await createOrGetChat(contact['name']!);
      
      // Add some sample messages
      await receiveMessage(
        chatId: chat.chatId,
        senderId: 'contact_${contact['name']!.toLowerCase().replaceAll(' ', '_')}',
        senderName: contact['name']!,
        content: contact['lastMessage']!,
      );
    }
  }

  Future<void> clearAllData() async {
    await _db.clearUserData(currentUserId);
  }
}
