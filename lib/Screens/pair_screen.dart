import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/settings.dart';
import '../services/chat_service.dart';
import 'new_chat_page.dart';

class PairScreen extends StatefulWidget {
  final bool autoHost;
  const PairScreen({super.key, this.autoHost = false});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  String? wsUrl;
  String status = 'Ready to generate QR code';
  StreamSubscription? _connectionRequestSubscription;
  StreamSubscription? _connectionStatusSubscription;
  final _scannerController = MobileScannerController();
  bool _handled = false;
  String? _displayName;
  String? _displayPhone;

  @override
  void initState() {
    super.initState();
    _listenToConnectionStatus();
    _loadProfile();
    if (widget.autoHost) {
      // Auto start hosting and show QR when navigated from the navbar button.
      _host();
    }
  }

  Future<void> _loadProfile() async {
    final s = SettingsService();
    await s.load();
    if (!mounted) return;
    setState(() {
      _displayName = s.username ?? 'My Profile';
      _displayPhone = s.phone ?? '';
    });
  }

  void _listenToConnectionStatus() {
    _connectionStatusSubscription = ChatService().connectionStream.listen((status) async {
      print('🔄 Connection status received: $status'); // Debug log
      if (status == 'chat_created' && mounted) {
        print('✅ Chat created event received, getting peer chat...'); // Debug log
        // Connection successful, get the chat and navigate
        final chat = await ChatService().getCurrentPeerChat();
        print('📱 Retrieved chat: ${chat?.chatId ?? 'null'}'); // Debug log
        if (chat != null) {
          print('🚀 Navigating to new chat page...'); // Debug log
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewChatPage(chat: chat),
            ),
          );
        } else {
          print('❌ No chat found from getCurrentPeerChat'); // Debug log
        }
      }
    });
  }

  Future<void> _host() async {
    try {
      setState(() => status = 'Starting host...');
      final url = await ChatService().startHost();
      setState(() {
        wsUrl = url;
        status = 'Show this QR to your peer';
      });
      
      // Listen for connection requests
      _connectionRequestSubscription = ChatService().connectionRequestStream.listen((request) {
        _showConnectionRequestDialog(
          request['requesterName'] as String,
          request['requesterId'] as String,
          request['socket'],
        );
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host started!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start host: $e')));
      }
      setState(() => status = 'Failed to start host');
    }
  }

  void _openScanner() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            height: 500,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _scannerController.stop();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          if (_handled) return;
                          
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final String? code = barcode.rawValue?.trim();
                            
                            if (code != null && (code.startsWith('ws://') || code.startsWith('wss://'))) {
                              print('📷 QR Code detected: $code'); // Debug log
                              _handled = true;
                              _scannerController.stop();
                              Navigator.of(context).pop(); // Close scanner dialog
                              _joinConnection(code);
                              // Also start waiting for chat creation
                              _waitForChatCreation();
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // Reset handled flag when dialog closes
      _handled = false;
    });
  }

  void _joinConnection(String url) async {
    try {
      print('🔗 Starting connection to: $url'); // Debug log
      setState(() => status = 'Connecting...');
      await ChatService().connectTo(url);
      
      print('📤 Connection request sent successfully'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent! Waiting for acceptance...'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Connection failed: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
      setState(() => status = 'Failed to connect');
    }
  }

  // Additional method to wait for chat creation and navigate
  void _waitForChatCreation() async {
    print('⏳ Starting to wait for chat creation...'); // Debug log
    // Wait for a reasonable time for the connection to be accepted and chat created
    for (int i = 0; i < 30; i++) { // Wait up to 30 seconds
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      
      final chat = await ChatService().getCurrentPeerChat();
      if (chat != null) {
        print('🎉 Chat found! Navigating to new chat page...'); // Debug log
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewChatPage(chat: chat),
            ),
          );
        }
        return;
      }
      print('⏱️ Still waiting for chat... (${i + 1}/30)'); // Debug log
    }
    print('⏰ Timeout waiting for chat creation'); // Debug log
  }

  Future<void> _showConnectionRequestDialog(String requesterName, String requesterId, dynamic socket) async {
    if (!mounted) return;
    
    print('Showing connection request dialog for: $requesterName'); // Debug log
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔗 Connection Request'),
          content: Text('$requesterName wants to start a chat with you.\n\nDo you accept this connection?'),
          actions: [
            TextButton(
              onPressed: () {
                print('User rejected connection request'); // Debug log
                Navigator.of(context).pop(false);
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                print('User accepted connection request'); // Debug log
                Navigator.of(context).pop(true);
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      print('Processing acceptance...'); // Debug log
      // Accept the connection
      await ChatService().acceptConnectionRequest(socket, requesterId, requesterName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection accepted! Chat created.')),
        );
        Navigator.pop(context, true);
      }
    } else {
      print('Processing rejection...'); // Debug log
      // Reject the connection
      await ChatService().rejectConnectionRequest(socket);
    }
  }

  @override
  void dispose() {
    _connectionRequestSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.purple, Colors.purpleAccent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // Simple status
                if (wsUrl == null)
                  Column(
                    children: [
                      const Icon(
                        Icons.qr_code_2,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Generate QR Code',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _host,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Generate QR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Show URL and allow copy for offline debugging/verification
                      if (wsUrl != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  wsUrl!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Copy',
                                icon: const Icon(Icons.copy, color: Colors.white),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: wsUrl!));
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('URL copied to clipboard')),
                                  );
                                },
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Add scan button here too
                      ElevatedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Just the QR Code - Large and prominent
                if (wsUrl != null)
                  Column(
                    children: [
                      // Profile header like in sample
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: const Icon(Icons.person, size: 40, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName ?? 'My QR Code',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if ((_displayPhone ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _displayPhone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'Your QR Code',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: wsUrl!,
                          version: QrVersions.auto,
                          size: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Color(0xFF4F67FF),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Ask others to scan this QR code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Simple Scan Button
                      ElevatedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
