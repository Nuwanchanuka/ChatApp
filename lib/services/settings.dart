import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _i = SettingsService._internal();
  factory SettingsService() => _i;
  SettingsService._internal();

  static const _kUsernameKey = 'username';
  static const _kPhoneKey = 'phone';
  static const _kBioKey = 'bio';
  static const _kExtendedChatsKey = 'extended_chats';

  String? _username;
  String? _phone;
  String? _bio;

  String? get username => _username;
  String? get phone => _phone;
  String? get bio => _bio;
  bool get hasUsername => (_username != null && _username!.trim().isNotEmpty);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_kUsernameKey);
    _phone = prefs.getString(_kPhoneKey);
    _bio = prefs.getString(_kBioKey);
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    String? bio,
  }) async {
    _username = name.trim();
    _phone = phone.trim();
    _bio = (bio ?? '').trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsernameKey, _username!);
    await prefs.setString(_kPhoneKey, _phone!);
    await prefs.setString(_kBioKey, _bio ?? '');
  }

  Future<void> saveUsername(String name) async {
    _username = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsernameKey, _username!);
  }

  Future<void> clearUsername() async {
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsernameKey);
  }

  Future<void> clearProfile() async {
    _username = null;
    _phone = null;
    _bio = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsernameKey);
    await prefs.remove(_kPhoneKey);
    await prefs.remove(_kBioKey);
  }

  // Extended/saved chat helpers
  Future<Set<String>> getExtendedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kExtendedChatsKey) ?? const [];
    return list.toSet();
  }

  Future<bool> isChatExtended(String chatId) async {
    final set = await getExtendedChats();
    return set.contains(chatId);
  }

  Future<void> setChatExtended(String chatId, bool extended) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_kExtendedChatsKey) ?? const []).toSet();
    if (extended) {
      set.add(chatId);
    } else {
      set.remove(chatId);
    }
    await prefs.setStringList(_kExtendedChatsKey, set.toList());
  }
}
