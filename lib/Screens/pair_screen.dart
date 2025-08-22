import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/chat_service.dart';

class PairScreen extends StatefulWidget {
  final bool autoHost;
  const PairScreen({super.key, this.autoHost = false});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  String? wsUrl;
  String status = 'Idle';
  final _joinController = TextEditingController();
  final _scannerController = MobileScannerController();
  bool _handled = false;

  Future<void> _host() async {
    try {
      setState(() => status = 'Starting host...');
      final url = await ChatService().startHost();
      setState(() {
        wsUrl = url;
        status = 'Show this QR to your peer';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hosting started. Scan the QR from peer.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to host: $e')));
      }
      setState(() => status = 'Failed to host');
    }
  }

  @override
  void dispose() {
  _joinController.dispose();
  _scannerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoHost) {
      // Auto start hosting and show QR when navigated from the navbar button.
      _host();
    }
  }

  Future<void> _join(String url) async {
    try {
      setState(() => status = 'Connecting...');
      await ChatService().connectTo(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
      setState(() => status = 'Failed to connect');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair via QR')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(status, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (wsUrl == null)
              ElevatedButton.icon(
                onPressed: _host,
                icon: const Icon(Icons.qr_code),
                label: const Text('Host & show QR'),
              ),
            if (wsUrl != null)
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: wsUrl!,
                    version: QrVersions.auto,
                    size: 240,
                  ),
                ),
              ),
            const Divider(),
            // QR scanner (not on web)
            if (!kIsWeb)
              Expanded(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (_handled) return;
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue;
                      if (raw != null && raw.startsWith('ws://')) {
                        _handled = true;
                        _scannerController.stop();
                        _join(raw);
                        break;
                      }
                    }
                  },
                ),
              ),
            if (kIsWeb) const Text('QR scanning disabled on web. Use URL join below.'),
            const SizedBox(height: 8),
            TextField(
              controller: _joinController,
              decoration: const InputDecoration(
                labelText: 'Enter URL to join (ws://...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                final raw = _joinController.text.trim();
                if (raw.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter URL')));
                  return;
                }
                _join(raw);
              },
              icon: const Icon(Icons.link),
              label: const Text('Join via URL'),
            ),
          ],
        ),
      ),
    );
  }
}
