import 'package:flutter/material.dart';
import '../services/settings.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _phoneController = TextEditingController();

  String _countryCode = '+94';
  String _countryLabel = 'LK +94';
  bool _syncToPhone = true; // placeholder, no-op for now
  bool _saving = false;

  final List<Map<String, String>> _countries = const [
    {'label': 'LK +94', 'code': '+94'},
    {'label': 'IN +91', 'code': '+91'},
    {'label': 'US +1', 'code': '+1'},
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final s = SettingsService();
    await s.load();
    final name = (s.username ?? '').trim();
    final parts = name.split(' ');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      _firstController.text = parts.first;
    }
    if (parts.length > 1) {
      _lastController.text = parts.sublist(1).join(' ');
    }

    final phone = (s.phone ?? '').trim();
    if (phone.startsWith('+94')) {
      _countryCode = '+94';
      _countryLabel = 'LK +94';
      _phoneController.text = phone.replaceFirst('+94', '').trim();
    } else if (phone.startsWith('+91')) {
      _countryCode = '+91';
      _countryLabel = 'IN +91';
      _phoneController.text = phone.replaceFirst('+91', '').trim();
    } else if (phone.startsWith('+1')) {
      _countryCode = '+1';
      _countryLabel = 'US +1';
      _phoneController.text = phone.replaceFirst('+1', '').trim();
    } else if (phone.isNotEmpty) {
      _phoneController.text = phone;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fullName = [_firstController.text.trim(), _lastController.text.trim()]
          .where((e) => e.isNotEmpty)
          .join(' ');
      final phoneDigits = _phoneController.text.trim();
      final fullPhone = _countryCode + (phoneDigits.startsWith('+') ? phoneDigits.substring(1) : phoneDigits);

      final s = SettingsService();
      await s.load();
      await s.saveProfile(
        name: fullName.isNotEmpty ? fullName : (s.username ?? 'User'),
        phone: fullPhone,
        bio: s.bio,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {Widget? prefixIcon}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: const Color.fromARGB(255, 254, 245, 112),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 213, 235, 94),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 208, 233, 119),
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit contact', style: TextStyle(color: Colors.black87)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Shadow box section containing the form fields
              Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 207, 221, 160),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _dec('First name', prefixIcon: const Icon(Icons.person_outline, color: Colors.black54)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _dec('Last name'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: InputDecorator(
                            decoration: _dec('Country'),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _countryLabel,
                                dropdownColor: const Color.fromARGB(255, 226, 230, 113),
                                items: _countries
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c['label']!,
                                          child: Text(c['label']!, style: const TextStyle(color: Colors.black87)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _countryLabel = v;
                                    _countryCode = _countries.firstWhere((e) => e['label'] == v)['code']!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _dec('Phone'),
                            validator: (v) => (v == null || v.trim().length < 6) ? 'Invalid phone' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sync contact to phone', style: TextStyle(color: Colors.black87)),
                      value: _syncToPhone,
                      activeColor: const Color(0xFF66BB6A),
                      onChanged: (v) => setState(() => _syncToPhone = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
