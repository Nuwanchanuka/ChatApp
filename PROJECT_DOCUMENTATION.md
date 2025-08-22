# ChatApp - Real-Time QR Code Based Chat Application

## Project Overview

ChatApp is an Android application that enables two users to initiate real-time chat sessions using QR code-based connections. The application allows strangers to quickly establish temporary chat sessions by scanning QR codes, making it perfect for spontaneous conversations at meetings, events, or social gatherings.

## Technical Implementation

### Technology Stack
- **Framework**: Flutter (Dart)
- **Database**: SQLite for local storage
- **Communication**: WebSocket for real-time messaging
- **QR Code**: mobile_scanner plugin for scanning, qr_flutter for generation
- **Target Platform**: Android 9+ (API level 28+)

### Architecture
The application follows a clean architecture pattern with clear separation of concerns:

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── chat_model.dart         # Chat conversation model
│   ├── message_model.dart      # Message data model
│   └── conversation.dart       # Legacy conversation model
├── services/                   # Business logic layer
│   ├── chat_service.dart       # WebSocket & chat management
│   ├── database_service.dart   # SQLite operations
│   ├── settings.dart           # User preferences
│   └── notification_service.dart # User notifications
├── screens/                    # UI screens
│   ├── new_home_screen.dart    # Main navigation screen
│   ├── profile_setup_screen.dart # User onboarding
│   ├── individual_chat_screen.dart # Chat interface
│   ├── pair_screen.dart        # QR code functionality
│   └── profile_screen.dart     # User profile
└── utils/                      # Utility classes
    └── logger.dart             # Debugging and logging
```

## Core Features Implementation

### 1. Core Chat Functionality (60 Marks)

#### User Interface
- **Modern Design**: Beautiful blue gradient UI with intuitive navigation
- **Bottom Navigation**: Three tabs - Chats, QR, Profile
- **Message Bubbles**: Distinct styling for sent/received messages
- **Chronological Display**: Messages ordered by timestamp
- **Real-time Updates**: Instant message delivery and display

#### Instant Messaging System
- **WebSocket Communication**: Real-time bidirectional communication
- **Message Delivery**: Robust handling of message transmission
- **Connection Management**: Automatic reconnection and error handling
- **Dual Database**: Both legacy and modern SQLite implementations

#### Text Input & Display
- **Rich Text Input**: Multi-line support with send button
- **Message Formatting**: Clean bubble interface with timestamps
- **Sender Identification**: Clear distinction between users
- **Input Validation**: Prevents empty message sending

#### Message Persistence (SQLite)
```sql
-- Chats Table
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
);

-- Messages Table
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
);
```

**Key Features:**
- User-isolated data storage
- Complete message history
- Unread message tracking
- Search functionality
- Data persistence across app restarts

### 2. QR Code Pairing & Connection (30 Marks)

#### QR Code Generation
- **Unique Code Generation**: Each session creates a unique WebSocket URL
- **Visual Display**: Clear QR code presentation with instructions
- **Auto-Host Mode**: Automatic server startup when generating QR
- **Connection Details**: Displays local IP and port information

#### QR Code Scanning
- **Camera Integration**: Uses device camera for QR scanning
- **Real-time Scanning**: Instant recognition and processing
- **Permission Handling**: Proper camera permission management
- **Error Handling**: Graceful handling of invalid QR codes

#### Automated Connection
```dart
// Connection establishment flow
1. Device A generates QR code containing WebSocket URL
2. Device B scans QR code and extracts URL
3. Device B connects to Device A's WebSocket server
4. Bidirectional communication channel established
5. Chat session begins automatically
```

**Connection Features:**
- Automatic peer discovery
- Connection status indicators
- Reconnection attempts
- Error recovery mechanisms

### 3. Versatility & Robustness (10 Marks)

#### Notifications
- **Success Messages**: Connection establishment confirmations
- **Error Alerts**: Connection failures and issues
- **Info Messages**: Status updates and guidance
- **Warning Notifications**: Connection problems

#### Exception Handling
- **Network Errors**: Graceful handling of connection issues
- **Database Errors**: Proper SQLite error management
- **UI Errors**: Safe navigation and state management
- **Permission Errors**: Appropriate fallbacks for camera access

## User Experience Flow

### 1. First Launch
1. **Profile Setup**: User enters name, phone number, and bio
2. **Beautiful Onboarding**: Gradient interface with form validation
3. **Data Storage**: Profile saved to local SQLite database

### 2. Main Interface
1. **Home Screen**: Tabbed interface with chat list
2. **Empty State**: Attractive "No chats yet" with call-to-action
3. **Navigation**: Smooth transitions between sections

### 3. Starting a Chat
1. **QR Generation**: Tap "Show QR" to host a connection
2. **QR Scanning**: Tap "Scan QR" to join someone's chat
3. **Auto Connection**: Instant chat session establishment

### 4. Chatting Experience
1. **Real-time Messaging**: Instant message delivery
2. **Message History**: Complete conversation persistence
3. **Connection Status**: Visual indicators for connection state

## Technical Highlights

### Performance Optimizations
- **Efficient Database Queries**: Indexed tables for fast retrieval
- **Memory Management**: Proper disposal of resources
- **Lazy Loading**: On-demand message loading for large chats
- **Connection Pooling**: Optimized WebSocket management

### Security Considerations
- **Local Network Only**: Connections limited to same Wi-Fi network
- **Temporary Sessions**: No permanent server infrastructure
- **Data Isolation**: User data separated by login credentials
- **Permission Security**: Proper Android permission handling

### Code Quality Features
- **Clean Architecture**: Separation of concerns
- **Comprehensive Logging**: Debug information for troubleshooting
- **Error Handling**: Graceful degradation on failures
- **Documentation**: Well-commented codebase
- **Type Safety**: Strong typing with Dart

## Installation & Setup

### Prerequisites
- Android device with API level 28+ (Android 9+)
- Camera permission for QR scanning
- Wi-Fi network for device-to-device communication

### Building the Application
```bash
# Clone the repository
git clone <repository-url>
cd ChatApp

# Install dependencies
flutter pub get

# Build APK
flutter build apk --release

# Install on device
flutter install
```

### Running in Development
```bash
# Run on connected device
flutter run

# Run with specific device
flutter run -d <device-id>

# Hot reload for development
flutter run --hot
```

## Testing Scenarios

### Basic Functionality Test
1. Install app on two Android devices
2. Connect both devices to same Wi-Fi network
3. Open app on both devices and complete profile setup
4. Device A: Tap QR tab → Show QR
5. Device B: Tap QR tab → Scan QR → Point camera at Device A's QR
6. Verify automatic connection establishment
7. Send messages from both devices
8. Verify real-time message delivery
9. Close and reopen app to verify message persistence

### Advanced Testing
- **Network Interruption**: Test reconnection behavior
- **App Backgrounding**: Verify state persistence
- **Multiple Sessions**: Test sequential connections
- **Error Scenarios**: Invalid QR codes, network failures

## Project Deliverables

### 1. Source Code
- Complete Flutter project with clean, commented code
- Git repository with commit history
- Proper project structure and organization

### 2. Documentation
- This comprehensive technical documentation
- Code comments explaining complex logic
- API documentation for services

### 3. Demonstration
- Video demonstration showing all features
- Step-by-step usage scenarios
- Performance and reliability showcase

### 4. Installable Build
- Release APK for direct installation
- Optimized for production use
- Tested on multiple devices

## Conclusion

ChatApp successfully implements all required features with a focus on user experience, code quality, and robustness. The application provides a seamless way for users to establish temporary chat sessions through QR code scanning, with full message persistence and real-time communication capabilities.

The technical implementation demonstrates proficiency in Flutter development, SQLite database management, WebSocket communication, and Android platform integration. The clean architecture and comprehensive error handling ensure a reliable and maintainable codebase suitable for production use.
