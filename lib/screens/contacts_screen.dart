import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/providers/call_provider.dart';
import '../core/providers/patient_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
      return;
    }

    // withProperties: true fetches phone numbers
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final sorted = List<Contact>.from(contacts)
      ..sort((a, b) =>
          (a.displayName).compareTo(b.displayName));
    setState(() {
      _contacts = sorted;
      _filtered = sorted;
      _isLoading = false;
    });
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _contacts.where((c) {
        final name = c.displayName.toLowerCase();
        final phone = c.phones.firstOrNull?.number ?? '';
        return name.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  Future<void> _callContact(Contact c) async {
    final number = c.phones.firstOrNull?.number ?? '';
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this contact')),
      );
      return;
    }
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      await context.read<CallProvider>().makeCall(clean);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  void _showDetail(Contact c) {
    final number = c.phones.firstOrNull?.number ?? '';
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactDetailSheet(
        contact: c,
        phoneNumber: clean,
        patientProvider: context.read<PatientProvider>(),
        onCall: () {
          Navigator.pop(ctx);
          _callContact(c);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Contacts permission required',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search,
                    color:
                        isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filtered.length} contacts',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text('No contacts found',
                      style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: _filtered.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final c = _filtered[index];
                    final phone = c.phones.firstOrNull?.number ?? 'No number';
                    final initials = c.displayName
                        .split(' ')
                        .map((e) => e.isEmpty ? '' : e[0])
                        .take(2)
                        .join()
                        .toUpperCase();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: _avatarColor(c.displayName),
                        child: Text(initials.isEmpty ? '?' : initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      title: Text(c.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(phone,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.call,
                            color: Color(0xFF1A56DB), size: 22),
                        onPressed: () => _callContact(c),
                      ),
                      onTap: () => _showDetail(c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ── Contact detail bottom sheet ───────────────────────────────────────────────
class _ContactDetailSheet extends StatefulWidget {
  final Contact contact;
  final String phoneNumber;
  final PatientProvider patientProvider;
  final VoidCallback onCall;

  const _ContactDetailSheet({
    required this.contact,
    required this.phoneNumber,
    required this.patientProvider,
    required this.onCall,
  });

  @override
  State<_ContactDetailSheet> createState() => _ContactDetailSheetState();
}

class _ContactDetailSheetState extends State<_ContactDetailSheet> {
  bool _loading = true;
  dynamic _patient;

  @override
  void initState() {
    super.initState();
    _lookupPatient();
  }

  Future<void> _lookupPatient() async {
    if (widget.phoneNumber.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final p = await widget.patientProvider.findByPhoneNumber(widget.phoneNumber);
    setState(() {
      _patient = p;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.contact.displayName;
    final initials = name
        .split(' ')
        .map((e) => e.isEmpty ? '' : e[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF1A56DB),
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
            widget.phoneNumber.isNotEmpty ? widget.phoneNumber : 'No number',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_patient != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_hospital,
                      color: Color(0xFF1A56DB), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Patient · ${_patient!.healthIssue}',
                    style: const TextStyle(
                        color: Color(0xFF1A56DB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            const Text('Not a registered patient',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onCall,
              icon: const Icon(Icons.call),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
