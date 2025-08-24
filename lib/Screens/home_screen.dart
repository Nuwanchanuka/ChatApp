import '../pages/chat_page.dart';
import 'pair_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatapp/services/settings.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../services/db.dart';
import '../models/conversation.dart';
import 'chat_list_screen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  bool _showChat = false; // start on Home; open chat from list
  String _activePeer = 'peer';
  late Future<List<Conversation>> _convosFuture;
  int _selectedTab = 0; // 0 = Old chats, 1 = New chats

  @override
  void initState() {
    super.initState();
  _convosFuture = DBService().getConversations();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showChat, // when showing chat, intercept back to go home
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // system is popping (on home), no-op
        if (_showChat) {
          setState(() => _showChat = false); // go Home instead of leaving app
          return;
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2027), Color(0xFF173447)],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(_showChat ? Icons.arrow_back : Icons.home),
          onPressed: () async {
            if (_showChat) {
              setState(() => _showChat = false);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
  title: const Text('Chat App', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Builder(
            builder: (context) {
              final name = SettingsService().username ?? 'You';
              String initials() {
                final parts = name.trim().split(RegExp(r"\s+"));
                final first = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
                final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
                final ini = ('$first$second').toUpperCase();
                return ini.isEmpty ? '?' : ini;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen(showBackButton: true)),
                    );
                    if (!mounted) return;
                    // Refresh AppBar to reflect any username change
                    setState(() {});
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Text(
                      initials(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Scan to connect',
            icon: const Icon(Icons.camera_alt),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PairScreen()),
              );
              if (!mounted) return;
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Show my QR',
            icon: const Icon(Icons.qr_code),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PairScreen(autoHost: true)),
              );
              if (!mounted) return;
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search not implemented')));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final nav = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Clear your username and go to Login?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Logout')),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await SettingsService().clearUsername();
                  if (!mounted) return;
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ];
            },
          )
        ],
  ),
      body: Column(
        children: [
          // Segmented control (Messages/Calls)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text(
                          'WebSocket Chats', 
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : Colors.white70, 
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'SQLite Chats', 
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : Colors.white70, 
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _showChat
                ? ChatPage(peer: _activePeer)
                : _selectedTab == 0
                    ? _buildWebSocketChats()
                    : const ChatListScreen(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWebSocketChats() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _convosFuture = DBService().getConversations();
        });
        await _convosFuture;
      },
      child: FutureBuilder<List<Conversation>>(
        future: _convosFuture,
        builder: (context, snap) {
          final data = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (data.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Icon(Icons.inbox, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Center(child: Text('No WebSocket chats yet', style: TextStyle(color: Colors.white70))),
              ],
            );
          }
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            itemBuilder: (context, i) {
              final c = data[i];
              final initials = (() {
                final parts = c.peer.trim().split(RegExp(r"\\s+"));
                final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
                final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
                final ini = ('$a$b').toUpperCase();
                return ini.isEmpty ? '?' : ini;
              })();
              return InkWell(
                onTap: () {
                  setState(() {
                    _activePeer = c.peer;
                    _showChat = true;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.peer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${c.lastSender == (SettingsService().username ?? 'You') ? 'You' : c.lastSender}: ${c.lastText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(c.lastTs.toLocal().toString().substring(11, 16), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          if (c.unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                              child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
