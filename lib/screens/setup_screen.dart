import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/providers/call_provider.dart';

/// Shown once on first launch to request all required permissions and
/// guide the user through battery optimization / default dialer setup.
class SetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupScreen({super.key, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<_PermStep> _steps = [
    _PermStep(
      icon: Icons.phone_in_talk,
      title: 'Phone & Call Log',
      subtitle: 'Detect incoming calls and read call history',
      permissions: [
        Permission.phone,
        Permission.microphone,
      ],
    ),
    _PermStep(
      icon: Icons.contacts,
      title: 'Contacts',
      subtitle: 'Show caller name from your address book',
      permissions: [Permission.contacts],
    ),
    _PermStep(
      icon: Icons.notifications_active,
      title: 'Notifications',
      subtitle: 'Show persistent service notification',
      permissions: [Permission.notification],
    ),
    _PermStep(
      icon: Icons.picture_in_picture,
      title: 'Display over other apps',
      subtitle: 'Show patient info during incoming calls',
      permissions: [Permission.systemAlertWindow],
      isSpecial: true,
    ),
  ];

  Map<int, bool> _granted = {};
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    for (int i = 0; i < _steps.length; i++) {
      bool allGranted = true;
      for (final p in _steps[i].permissions) {
        final s = await p.status;
        if (!s.isGranted) { allGranted = false; break; }
      }
      _granted[i] = allGranted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestStep(int index) async {
    final step = _steps[index];
    setState(() => _checking = true);
    if (step.isSpecial) {
      // Special permissions need openAppSettings
      for (final p in step.permissions) {
        final s = await p.status;
        if (!s.isGranted) await openAppSettings();
      }
    } else {
      await step.permissions.request();
    }
    await _checkAll();
    setState(() => _checking = false);
  }

  bool get _allGranted => _granted.values.isNotEmpty &&
      _granted.values.every((v) => v == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medical_services,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MedCaller Setup',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('Grant permissions to continue',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Permission cards
              Expanded(
                child: ListView.separated(
                  itemCount: _steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final step = _steps[i];
                    final granted = _granted[i] ?? false;
                    return _PermCard(
                      step: step,
                      granted: granted,
                      onGrant: _checking ? null : () => _requestStep(i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Battery optimization card
              _BatteryCard(),
              const SizedBox(height: 16),
              // Default dialer card
              _DefaultDialerCard(),
              const SizedBox(height: 24),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allGranted ? widget.onComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allGranted
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue to MedCaller',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (!_allGranted)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('Skip for now',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission card ───────────────────────────────────────────────────────────
class _PermCard extends StatelessWidget {
  final _PermStep step;
  final bool granted;
  final VoidCallback? onGrant;

  const _PermCard({
    required this.step,
    required this.granted,
    this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: granted
            ? const Color(0xFF0F2A1A)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? const Color(0xFF16A34A)
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (granted ? const Color(0xFF16A34A) : const Color(0xFF1A56DB))
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              color: granted ? const Color(0xFF4ADE80) : const Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(step.subtitle,
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 24)
              : GestureDetector(
                  onTap: onGrant,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Grant',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Battery optimization card ─────────────────────────────────────────────────
class _BatteryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.battery_charging_full,
                color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Battery Optimization',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text('Disable to keep app always running',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.read<CallProvider>().requestIgnoreBatteryOptimization();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Text('Disable',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Default dialer card ───────────────────────────────────────────────────────
class _DefaultDialerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cp.isDefaultDialer
            ? const Color(0xFF0F2A1A)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cp.isDefaultDialer
              ? const Color(0xFF16A34A)
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (cp.isDefaultDialer
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF7C3AED))
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dialer_sip,
              color: cp.isDefaultDialer
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFA78BFA),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set as Default Dialer',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text('Required for full incoming call support',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          cp.isDefaultDialer
              ? const Icon(Icons.check_circle,
                  color: Color(0xFF4ADE80), size: 24)
              : GestureDetector(
                  onTap: () => cp.requestDefaultDialer(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                    ),
                    child: const Text('Set',
                        style: TextStyle(
                            color: Color(0xFFA78BFA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────
class _PermStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Permission> permissions;
  final bool isSpecial;

  const _PermStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.permissions,
    this.isSpecial = false,
  });
}
