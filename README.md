# ChatApp – QR paired chat (Flutter)

This app lets two Android devices start a temporary chat by pairing via QR code.
One device hosts a WebSocket server on the local network and shows a QR that encodes the ws:// URL. The other device scans and connects. Messages are stored locally in SQLite.

Features
- QR generate/scan for pairing
- Real-time messages over WebSocket (LAN)
- Local chat history (SQLite)
- Simple WhatsApp-like UI and toasts

Run
1) Ensure two devices are on the same Wi‑Fi network.
2) In VS Code, press F5 (config: “Flutter: Run main.dart”).
3) In the CHATS tab, tap “Pair” (QR icon).
	- Device A: Tap “Host & show QR” and keep the QR visible.
	- Device B: Point the camera to the QR and connect.
4) Start chatting. History persists locally.

Build APK
- Debug: flutter build apk
- Release: flutter build apk --release

Notes
- Camera permission is required for scanning.
- Cleartext traffic is enabled for LAN ws:// URLs.
