# ChatApp – QR paired chat (Flutter)

This app lets two Android devices start a # ChatApp - Real-Time Mobile Chat Application

## Overview
A Flutter-based Android chat application that enables real-time communication between two users through QR code-based connection establishment.

## Architecture

### Core Components
- **Frontend**: Flutter UI with Material Design
- **Backend**: WebSocket server for real-time communication
- **Database**: SQLite for local message persistence
- **Connection**: QR code-based device pairing

### Key Features
1. **Real-time Messaging**: WebSocket-based instant messaging
2. **QR Code Pairing**: Camera-based connection establishment
3. **Local Storage**: SQLite database for chat history
4. **User Profiles**: Complete profile management system
5. **Modern UI**: Beautiful gradient design with intuitive navigation

## Technical Implementation

### Database Schema
```sql
-- Chats table
CREATE TABLE chats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL,
  name TEXT NOT NULL,
  last_message TEXT,
  last_message_time INTEGER,
  unread_count INTEGER DEFAULT 0,
  user_id TEXT NOT NULL
);

-- Messages table  
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL,
  chat_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  content TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  user_id TEXT NOT NULL
);
```

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── chat_model.dart      # Chat data model
│   ├── message_model.dart   # Message data model
│   └── conversation.dart    # Legacy conversation model
├── services/
│   ├── chat_service.dart    # Chat business logic
│   ├── database_service.dart # SQLite operations
│   ├── settings.dart        # User preferences
│   └── db.dart             # Legacy database service
├── screens/
│   ├── new_home_screen.dart     # Main home screen
│   ├── profile_setup_screen.dart # User onboarding
│   ├── profile_screen.dart      # User profile
│   ├── chat_list_screen.dart    # Chat list view
│   ├── individual_chat_screen.dart # Chat interface
│   └── pair_screen.dart         # QR code pairing
└── pages/
    └── chat_page.dart       # Legacy chat page
```

## Features Implementation

### 1. Core Chat Functionality ✅
- **Real-time messaging** with WebSocket
- **Message persistence** using SQLite
- **Chat history** with timestamps
- **Multiple conversations** support
- **Unread message tracking**

### 2. QR Code Pairing ✅
- **QR code generation** for connection
- **Camera scanning** functionality
- **Automatic pairing** on scan
- **Network connection** establishment

### 3. User Interface ✅
- **Modern gradient design**
- **Intuitive navigation** with bottom tabs
- **Responsive layouts** for all screens
- **Empty states** with call-to-action
- **Smooth animations** throughout

### 4. Profile Management ✅
- **User registration** with phone/name/bio
- **Profile editing** capabilities
- **Data persistence** across sessions
- **Logout functionality** with data clearing

## Installation & Setup

### Build Commands
```bash
# Install dependencies
flutter pub get

# Run on device
flutter run

# Build APK
flutter build apk --release
```

---
**Developed with Flutter for Android 9+ compatibility**
**Supports real-time communication via WebSocket + SQLite persistence** by pairing via QR code.
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
