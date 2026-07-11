import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/call_provider.dart';
import '../core/providers/patient_provider.dart';
import '../core/models/patient.dart';
import 'contacts_screen.dart';
import 'call_history_screen.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _dialedNumber = '';
  Patient? _matchedPatient;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String value) {
    setState(() => _dialedNumber += value);
    _lookupPatient();
  }

  void _onDelete() {
    if (_dialedNumber.isNotEmpty) {
      setState(
          () => _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1));
      _lookupPatient();
    }
  }

  Future<void> _lookupPatient() async {
    final number = _dialedNumber;
    if (number.length < 7) {
      setState(() => _matchedPatient = null);
      return;
    }
    setState(() => _looking = true);
    final p = await context.read<PatientProvider>().findByPhoneNumber(number);
    if (mounted && _dialedNumber == number) {
      setState(() {
        _matchedPatient = p;
        _looking = false;
      });
    }
  }

  Future<void> _makeCall() async {
    if (_dialedNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number to call')),
      );
      return;
    }
    try {
      await context.read<CallProvider>().makeCall(_dialedNumber);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar
            Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1A56DB),
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: const Color(0xFF1A56DB),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.dialpad), text: 'Dialer'),
                  Tab(icon: Icon(Icons.contacts_outlined), text: 'Contacts'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDialerTab(isDark),
                  const ContactsScreen(),
                  const CallHistoryScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialer tab ─────────────────────────────────────────────────────────────
  Widget _buildDialerTab(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Patient badge (shows when number matches)
        if (_looking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_matchedPatient != null)
          _buildPatientBadge(_matchedPatient!)
        else
          const SizedBox(height: 12),

        // Number display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _dialedNumber.isEmpty ? 'Enter number' : _formatDisplay(_dialedNumber),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _dialedNumber.isEmpty ? 18 : 30,
                    fontWeight: FontWeight.w300,
                    color: _dialedNumber.isEmpty
                        ? const Color(0xFF94A3B8)
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    letterSpacing: 2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_dialedNumber.isNotEmpty)
                GestureDetector(
                  onTap: _onDelete,
                  onLongPress: () => setState(() {
                    _dialedNumber = '';
                    _matchedPatient = null;
                  }),
                  child: Icon(
                    Icons.backspace_outlined,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),
        const SizedBox(height: 16),

        // Keypad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _keyRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                _keyRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                _keyRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                _keyRow(['*', '0', '#'], ['', '+', '']),
              ],
            ),
          ),
        ),

        // Call button
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          child: GestureDetector(
            onTap: _makeCall,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.call, color: Colors.white, size: 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientBadge(Patient p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1A56DB),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    p.healthIssue,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (p.isHighRisk)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'HIGH RISK',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Format typed number for display (groups of 5)
  String _formatDisplay(String number) {
    if (number.length <= 5) return number;
    if (number.length <= 10) {
      return '${number.substring(0, 5)} ${number.substring(5)}';
    }
    return number;
  }

  Widget _keyRow(List<String> digits, List<String> subs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) => _keyButton(digits[i], subs[i])),
    );
  }

  Widget _keyButton(String digit, String sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onKeyPressed(digit),
      onLongPress: digit == '0' ? () => _onKeyPressed('+') : null,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
