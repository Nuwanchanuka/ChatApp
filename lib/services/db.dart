import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class DBService {
  static final DBService _i = DBService._internal();
  factory DBService() => _i;
  DBService._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'chat.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            peer TEXT,
            sender TEXT,
            text TEXT,
            ts INTEGER
          );
        ''');
      },
    );
    return _db!;
  }

  Future<void> insertMessage({required String peer, required String id, required String sender, required String text, required DateTime ts}) async {
    final d = await db;
    await d.insert('messages', {
      'id': id,
      'peer': peer,
      'sender': sender,
      'text': text,
      'ts': ts.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Message>> getMessages(String peer) async {
    final d = await db;
    final rows = await d.query('messages', where: 'peer = ?', whereArgs: [peer], orderBy: 'ts ASC');
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  Future<List<Conversation>> getConversations() async {
    final d = await db;
    // For each peer, get the last message by max(ts)
    final rows = await d.rawQuery('''
      SELECT m1.peer, m1.sender as lastSender, m1.text as lastText, m1.ts as lastTs
      FROM messages m1
      INNER JOIN (
        SELECT peer, MAX(ts) as maxTs
        FROM messages
        GROUP BY peer
      ) m2 ON m1.peer = m2.peer AND m1.ts = m2.maxTs
      ORDER BY m1.ts DESC
    ''');
    // naive unread: count messages in each peer where sender != 'You'/current user
    final convos = <Conversation>[];
    for (final r in rows) {
      final peer = r['peer'] as String;
      final cnt = Sqflite.firstIntValue(await d.rawQuery(
        'SELECT COUNT(*) FROM messages WHERE peer = ? AND sender != ?',
        [peer, 'You'],
      )) ?? 0;
      convos.add(Conversation(
        peer: peer,
        lastSender: r['lastSender'] as String,
        lastText: r['lastText'] as String,
        lastTs: DateTime.fromMillisecondsSinceEpoch(r['lastTs'] as int),
        unread: cnt,
      ));
    }
    return convos;
  }
}
