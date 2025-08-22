import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chatapp.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create chats table
    await db.execute('''
      CREATE TABLE chats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id TEXT NOT NULL,
        name TEXT NOT NULL,
        last_message TEXT,
        last_message_time INTEGER,
        avatar TEXT,
        unread_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        UNIQUE(chat_id, user_id)
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL,
        chat_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'text',
        timestamp INTEGER NOT NULL,
        is_read INTEGER DEFAULT 0,
        user_id TEXT NOT NULL,
        UNIQUE(message_id, user_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_chats_user_id ON chats(user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_chat_id ON messages(chat_id, user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp ON messages(timestamp)
    ''');
  }

  // Chat operations
  Future<int> insertChat(Chat chat) async {
    final db = await database;
    return await db.insert(
      'chats',
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Chat>> getChats(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'last_message_time DESC, created_at DESC',
    );

    return List.generate(maps.length, (i) => Chat.fromMap(maps[i]));
  }

  Future<Chat?> getChat(String chatId, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chats',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Chat.fromMap(maps.first);
  }

  Future<int> updateChat(Chat chat) async {
    final db = await database;
    return await db.update(
      'chats',
      chat.toMap(),
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chat.chatId, chat.userId],
    );
  }

  Future<int> deleteChat(String chatId, String userId) async {
    final db = await database;
    // Delete messages first
    await db.delete(
      'messages',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
    );
    // Then delete chat
    return await db.delete(
      'chats',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
    );
  }

  // Message operations
  Future<int> insertMessage(Message message) async {
    final db = await database;
    final result = await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update chat's last message
    await _updateChatLastMessage(message);
    return result;
  }

  Future<List<Message>> getMessages(String chatId, String userId, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => Message.fromMap(maps[i])).reversed.toList();
  }

  Future<int> markMessagesAsRead(String chatId, String userId) async {
    final db = await database;
    final result = await db.update(
      'messages',
      {'is_read': 1},
      where: 'chat_id = ? AND user_id = ? AND is_read = 0',
      whereArgs: [chatId, userId],
    );

    // Reset unread count for chat
    await db.update(
      'chats',
      {'unread_count': 0},
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [chatId, userId],
    );

    return result;
  }

  Future<int> getUnreadMessageCount(String chatId, String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE chat_id = ? AND user_id = ? AND is_read = 0',
      [chatId, userId],
    );
    return result.first['count'] as int;
  }

  Future<void> _updateChatLastMessage(Message message) async {
    final db = await database;
    await db.update(
      'chats',
      {
        'last_message': message.content,
        'last_message_time': message.timestamp.millisecondsSinceEpoch,
      },
      where: 'chat_id = ? AND user_id = ?',
      whereArgs: [message.chatId, message.userId],
    );
  }

  // Search messages
  Future<List<Message>> searchMessages(String query, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'user_id = ? AND content LIKE ?',
      whereArgs: [userId, '%$query%'],
      orderBy: 'timestamp DESC',
      limit: 100,
    );

    return List.generate(maps.length, (i) => Message.fromMap(maps[i]));
  }

  // Clear all data for a user
  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.delete('messages', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('chats', where: 'user_id = ?', whereArgs: [userId]);
  }

  // Database utilities
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
