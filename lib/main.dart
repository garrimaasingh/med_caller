import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/models/patient.dart';
import 'core/providers/call_provider.dart';
import 'core/providers/patient_provider.dart';
import 'core/providers/tele_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/ai_settings.dart';
import 'screens/in_call_screen.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// ── Overlay entry point ────────────────────────────────────────────────────────
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization overlay error: $e");
  }
  runApp(const OverlayApp());
}

// ── App entry point ────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => TeleProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AiSettingsProvider()..load()),
        ChangeNotifierProvider(
          create: (_) {
            final cp = CallProvider();
            cp.initialize().then((_) => cp.startBackgroundService());
            return cp;
          },
        ),
      ],
      child: const MedCallerApp(),
    ),
  );
}

// ── Main App ───────────────────────────────────────────────────────────────────
class MedCallerApp extends StatefulWidget {
  const MedCallerApp({super.key});

  @override
  State<MedCallerApp> createState() => _MedCallerAppState();
}

class _MedCallerAppState extends State<MedCallerApp> {
  final _navKey = GlobalKey<NavigatorState>();
  bool _inCallShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<CallProvider>().addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    final cp = context.read<CallProvider>();
    if (cp.isInCall && !_inCallShowing) {
      _inCallShowing = true;
      _navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const InCallScreen(),
          fullscreenDialog: true,
        ),
      ).then((_) {
        _inCallShowing = false;
      });
    }
  }

  @override
  void dispose() {
    context.read<CallProvider>().removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'MedCaller',
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}

// ── Auth gate + first-launch setup ────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _setupDone = true; // assume done until checked
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('setup_complete') ?? false;
    setState(() {
      _setupDone = done;
      _loading = false;
    });
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    setState(() => _setupDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator()));
    }

    if (!_setupDone) {
      return SetupScreen(onComplete: _completeSetup);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
    );
  }
}

// ── Overlay App (separate isolate) ────────────────────────────────────────────
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _OverlayContent(),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent();

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  Patient? _patient;
  bool _isLoading = true;
  bool _patientFound = false;
  String _displayNumber = '';

  @override
  void initState() {
    super.initState();
    _listenForNumber();
  }

  void _listenForNumber() {
    FlutterOverlayWindow.overlayListener.listen((event) async {
      final rawNumber = event?.toString() ?? '';
      debugPrint('[Overlay] Received: "$rawNumber"');

      setState(() {
        _isLoading = true;
        _patientFound = false;
        _displayNumber = rawNumber;
        _patient = null;
      });

      if (rawNumber.isEmpty) {
        // Number unavailable — show "Unknown caller" fallback immediately
        setState(() => _isLoading = false);
        return;
      }

      // Try multiple number format variants to maximize Firestore match chance
      final variants = _buildVariants(rawNumber);
      debugPrint('[Overlay] Trying variants: $variants');

      try {
        final service = PatientProvider();
        Patient? found;
        for (final v in variants) {
          found = await service.findByPhoneNumber(v);
          if (found != null) {
            debugPrint('[Overlay] Match found with: $v');
            break;
          }
        }
        if (found != null) {
          setState(() {
            _patient = found;
            _patientFound = true;
            _isLoading = false;
          });
        } else {
          debugPrint('[Overlay] No patient matched any variant');
          setState(() => _isLoading = false);
          // Do NOT auto-close — show "Not a registered patient" card
        }
      } catch (e) {
        debugPrint('[Overlay] Firestore error: $e');
        setState(() => _isLoading = false);
      }
    });
  }

  /// Generate number variants to match different Firestore storage formats.
  List<String> _buildVariants(String raw) {
    final variants = <String>{raw};
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    variants.add(digits);

    if (digits.length == 12 && digits.startsWith('91')) {
      variants.add(digits.substring(2)); // strip +91
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      variants.add(digits.substring(1)); // strip 0 prefix
    }
    if (digits.length == 10) {
      variants.add('+91$digits');
      variants.add('91$digits');
      variants.add('0$digits');
    }
    return variants.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _patientFound && _patient != null
                ? _buildPatientCard()
                : _buildFallbackCard(),
      ),
    );
  }

  // ── Fallback card (unknown number or not a patient) ──────────────────────────
  Widget _buildFallbackCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF64748B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Incoming Call',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      _displayNumber.isNotEmpty ? _displayNumber : 'Unknown Number',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.person_off_outlined, color: Color(0xFF94A3B8), size: 20),
              SizedBox(width: 10),
              Text('Not a registered patient',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF64748B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child:
                  const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Patient card ───────────────────────────────────────────────────────────────
  Widget _buildPatientCard() {
    final p = _patient!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A56DB),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Incoming Patient Call',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    Text(p.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (p.isHighRisk)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('HIGH RISK',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _infoRow(Icons.local_hospital_outlined, 'Health Issue', p.healthIssue),
              const Divider(height: 16),
              _infoRow(Icons.medication_outlined, 'Medication', p.medication),
              const Divider(height: 16),
              _infoRow(Icons.note_alt_outlined, 'Notes', p.notes),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => FlutterOverlayWindow.closeOverlay(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF1A56DB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Dismiss',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A56DB)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
              Text(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
