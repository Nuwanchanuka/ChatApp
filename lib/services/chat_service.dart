import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'db.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'database_service.dart';
import 'settings.dart';

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
  final _connectionRequest = StreamController<Map<String, dynamic>>.broadcast();
  
  // New database service integration
  final DatabaseService _db = DatabaseService();

  Stream<void> get incomingStream => _incoming.stream;
  Stream<String> get connectionStream => _connection.stream;
  Stream<Map<String, dynamic>> get connectionRequestStream => _connectionRequest.stream;

  bool get isConnected => _socket != null;
  
  String get currentUserId => SettingsService().username ?? 'anonymous';

  Future<String?> _localIpv4() async {
    // Try to pick a LAN-reachable IP. Prefer Wi‑Fi/hotspot interfaces and avoid
    // emulator-only subnets like 10.0.2.x which are not reachable from other devices.
    final nics = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    String? fallback;

    bool _isEmulatorSubnet(String ip) => ip.startsWith('10.0.2.');
    bool _isPrivate172(String ip) {
      // Match 172.16.0.0 – 172.31.255.255
      if (!ip.startsWith('172.')) return false;
      final parts = ip.split('.');
      if (parts.length < 2) return false;
      final second = int.tryParse(parts[1]) ?? -1;
      return second >= 16 && second <= 31;
    }

    for (final nic in nics) {
      final name = nic.name.toLowerCase();
      final isWifi = name.contains('wlan') || name.contains('wifi');
      final isHotspot = name.contains('ap') || name.contains('softap');

      for (final addr in nic.addresses) {
        final ip = addr.address;
        if (addr.isLoopback) continue;
        final isEmu = _isEmulatorSubnet(ip);
        final isPrivate = ip.startsWith('192.168.') || ip.startsWith('10.') || _isPrivate172(ip);

        // Most desirable: Wi‑Fi/Hotspot private address that is not emulator subnet
        if ((isWifi || isHotspot) && isPrivate && !isEmu) {
          return ip;
        }

        // Accept any non-emulator private address as a fallback
        if (fallback == null && isPrivate && !isEmu) {
          fallback = ip;
        }
      }
    }

    // As a last resort return whatever non-loopback we saw first
    if (fallback != null) return fallback;
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
    // Bind on all interfaces so peers on same Wi-Fi can connect
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
  _server!.listen((HttpRequest req) async {
      if (req.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
    final remoteIp = req.connectionInfo?.remoteAddress.address;
    final ws = await WebSocketTransformer.upgrade(req);
        _socket = ws;
  _connection.add('connected');
    peerId = remoteIp ?? peerId ?? 'peer';
        ws.listen((data) async {
          try {
            final m = jsonDecode(data as String) as Map<String, dynamic>;
            print('Host received message: $m'); // Debug log
            
            // Handle different message types
            if (m['type'] == 'connection_request') {
              print('Host received connection request from: ${m['requesterName']}'); // Debug log
              // Host receives connection request
              _connectionRequest.add({
                'requesterName': m['requesterName'],
                'requesterId': m['requesterId'],
                'socket': ws,
              });
              return;
            }
            
            // Regular chat message
            if (m['type'] == 'message' || m['id'] != null) {
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
            }
            
            _incoming.add(null);
          } catch (e) {
            print('Host error processing message: $e'); // Debug log
          }
        }, onDone: () {
          _socket = null;
          _connection.add('disconnected');
        }, onError: (e) {
          _socket = null;
          _connection.add('error:$e');
        });
      } else {
        req.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });
    final url = await serverWsUrl;
    if (url == null) {
      throw Exception('Could not determine local IP');
    }
    return url;
  }

  Future<void> connectTo(String wsUrl, {String? peer}) async {
    peerId = peer ?? Uri.parse(wsUrl).host;
    print('Connecting to: $wsUrl with peerId: $peerId'); // Debug log
    _socket = await WebSocket.connect(wsUrl);
    _connection.add('connected');
    
    // Send connection request instead of immediately creating chat
    final userSettings = SettingsService();
    await userSettings.load();
    final requesterName = userSettings.username?.isNotEmpty == true 
        ? userSettings.username! 
        : 'User ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    final request = {
      'type': 'connection_request',
      'requesterName': requesterName,
      'requesterId': peerId,
    };
    print('Sending connection request: $request'); // Debug log
    _socket!.add(jsonEncode(request));
    
    _socket!.listen((data) async {
      try {
        final m = jsonDecode(data as String) as Map<String, dynamic>;
        print('Received message: $m'); // Debug log
        
        // Handle different message types
        if (m['type'] == 'connection_accepted') {
          print('Connection accepted, creating chat...'); // Debug log
          // Client receives acceptance - create chat
          final hostName = (m['hostName'] as String?)?.trim();
          await _createChatForConnection(displayName: (hostName != null && hostName.isNotEmpty) ? hostName : null);
          _connection.add('chat_created');
          return;
        }
        
        if (m['type'] == 'connection_rejected') {
          print('Connection rejected'); // Debug log
          // Client receives rejection
          _connection.add('connection_rejected');
          return;
        }
        
        // Regular chat message
        if (m['type'] == 'message' || m['id'] != null) {
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
        }
      } catch (e) {
        print('Error processing message: $e'); // Debug log
      }
    }, onDone: () {
      _socket = null;
      _connection.add('disconnected');
    }, onError: (e) {
      _socket = null;
      _connection.add('error:$e');
    });
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

  // Create chat when connection is established
  Future<Chat> _createChatForConnection({String? displayName}) async {
    if (peerId == null) {
      throw Exception('No peer ID available');
    }
    
    // Generate a friendly name for the peer
    final fallback = 'Contact ${peerId!.split('.').last}';
    final peerName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : fallback;
    
    // Create or get existing chat, then ensure name is correct
    var chat = await createOrGetChat(peerName, contactId: peerId);
    if (chat.name != peerName && peerName.isNotEmpty) {
      final updated = chat.copyWith(name: peerName);
      await _db.updateChat(updated);
      chat = updated;
    }
    
    // Send an initial connection message
    await receiveMessage(
      chatId: chat.chatId,
      senderId: peerId!,
      senderName: peerName,
      content: '👋 Connected via QR code!',
    );
    
    return chat;
  }

  // Get the current chat for connected peer
  Future<Chat?> getCurrentPeerChat() async {
    if (peerId == null) return null;
    return await getChat(peerId!);
  }

  // Accept connection request
  Future<void> acceptConnectionRequest(WebSocket socket, String requesterId, String requesterName) async {
    print('Accepting connection request from: $requesterName ($requesterId)'); // Debug log
    // Create chat for host
    peerId = requesterId;
    _socket = socket;
  await _createChatForConnection(displayName: requesterName);
    
    // Send acceptance to client
    final response = {
      'type': 'connection_accepted',
      'hostName': (await SettingsService()..load()).username ?? 'Host',
    };
    print('Sending acceptance response: $response'); // Debug log
    socket.add(jsonEncode(response));
    
    _connection.add('chat_created');
  }

  // Reject connection request
  Future<void> rejectConnectionRequest(WebSocket socket) async {
    print('Rejecting connection request'); // Debug log
    socket.add(jsonEncode({
      'type': 'connection_rejected',
    }));
  }
}
