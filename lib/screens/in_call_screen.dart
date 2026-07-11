import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/providers/call_provider.dart';
import '../core/providers/patient_provider.dart';
import '../core/models/patient.dart';
import '../widgets/ai_quick_summary_card.dart';
import 'patient_detail_screen.dart';
import 'ai_live_call_screen.dart';
import 'add_edit_patient_screen.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> with SingleTickerProviderStateMixin {
  Patient? _patient;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  // Colors
  static const Color colorMedicalGreen = Color(0xFF218C5E);
  static const Color colorDarkBlue = Color(0xFF1B2838);

  bool _showSuccessOverlay = false;
  Patient? _recentlyAddedPatient;
  bool _showDialpad = false;
  String _dialpadBuffer = '';

  String get _displayName {
    if (_patient != null) return _patient!.name;
    final cp = context.read<CallProvider>();
    if (cp.callerName.isNotEmpty) return cp.callerName;
    return cp.number.isNotEmpty ? cp.number : 'Unknown Number';
  }

  bool get _isUnknown => _patient == null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPatient();
    });
  }

  void _fetchPatient() async {
    final cp = context.read<CallProvider>();
    if (cp.number.isNotEmpty) {
      final pp = context.read<PatientProvider>();
      final p = await pp.findByPhoneNumber(cp.number);
      if (mounted) setState(() => _patient = p);
    }
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  String get _durationStr {
    final m = _callDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _callDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<CallProvider>().state;
    if (state == CallState.active && !(_durationTimer?.isActive ?? false)) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, cp, _) {
        if (cp.state == CallState.ended || cp.state == CallState.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          });
        }
        if (cp.state == CallState.active && !(_durationTimer?.isActive ?? false)) {
          _startTimer();
        }

        final bgColor = (_isUnknown || _showSuccessOverlay) ? colorDarkBlue : colorMedicalGreen;

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _showSuccessOverlay ? const SizedBox(height: 8) : _buildTopText(cp),
                if (_showSuccessOverlay)
                  Expanded(child: SingleChildScrollView(child: _buildSuccessOverlay()))
                else if (_showDialpad) ...[
                  const SizedBox(height: 16),
                  _buildDialpadHeader(),
                  const Spacer(),
                  _buildDialpad(cp),
                  const Spacer(),
                  _buildCallControls(cp),
                  const SizedBox(height: 24),
                ] else ...[
                  // Scrollable content to prevent overflow
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildCallerAvatar(cp),
                          const SizedBox(height: 12),
                          _buildCallerDetails(),
                          const SizedBox(height: 16),
                          if (_isUnknown)
                            _buildUnknownNotice()
                          else
                            _buildPatientInfoCard(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _buildCallControls(cp),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopText(CallProvider cp) {
    String text = 'Incoming Call';
    if (cp.state == CallState.active) text = 'Ongoing Call - $_durationStr';
    else if (cp.state == CallState.dialing) text = 'Dialing...';
    
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildCallerAvatar(CallProvider cp) {
    return ScaleTransition(
      scale: cp.state == CallState.ringing ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: _isUnknown ? const Color(0xFF334155) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          image: !_isUnknown ? const DecorationImage(
            // Placeholder for real image
            image: NetworkImage('https://i.pravatar.cc/150?img=11'),
            fit: BoxFit.cover,
          ) : null,
        ),
        child: _isUnknown ? const Icon(Icons.person, color: Color(0xFF94A3B8), size: 48) : null,
      ),
    );
  }

  Widget _buildCallerDetails() {
    return Column(
      children: [
        Text(
          _displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.read<CallProvider>().number.isNotEmpty ? context.read<CallProvider>().number : 'India',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!_isUnknown && _patient != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _patient!.status == 'improving' ? const Color(0xFF10B981) : 
                           _patient!.status == 'recovering' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _patient!.status.replaceFirst(RegExp('^.'), _patient!.status.isEmpty ? '' : _patient!.status[0].toUpperCase()),
                  style: TextStyle(
                    color: _patient!.status == 'improving' ? const Color(0xFF047857) : 
                           _patient!.status == 'recovering' ? const Color(0xFFB45309) : const Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              ],
            ),
          ),
          if (_patient!.aiSummary != null && _patient!.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text('AI Notes', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _patient!.aiSummary!.replaceAll('\n', ' ').trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ]
        ]
      ],
    );
  }

  Widget _buildUnknownNotice() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unknown Number', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('Not in your patient list', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Do you want to add this\nnumber to your patient list?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), // Red
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 8),
                const Text('Ignore', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 48),
            GestureDetector(
              onTap: () async {
                final cp = context.read<CallProvider>();
                final num = cp.number.isNotEmpty ? cp.number : cp.callerName;
                final newPatient = await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEditPatientScreen(initialPhoneNumber: num),
                ));
                if (newPatient != null && newPatient is Patient) {
                   setState(() {
                      _recentlyAddedPatient = newPatient;
                      _showSuccessOverlay = true;
                   });
                   // Optional: automatically switch to Known Caller view after a few seconds
                   // Future.delayed(const Duration(seconds: 3), () {
                   //   if (mounted) {
                   //     setState(() { _showSuccessOverlay = false; _patient = newPatient; });
                   //   }
                   // });
                }
              },
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), // Green
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text('Add as Patient', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessOverlay() {
    final p = _recentlyAddedPatient;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 10,
              )
            ]
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 60),
        ),
        const SizedBox(height: 32),
        const Text('Patient Added\nSuccessfully!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('This number has been saved\nin your patient list.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
        const SizedBox(height: 40),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        p?.name.isNotEmpty == true ? p!.name[0].toUpperCase() : 'P',
                        style: const TextStyle(color: Color(0xFF166534), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p?.name ?? 'Unknown', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(p?.phoneNumber ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  if (p != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => PatientDetailScreen(patient: p)),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF218C5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Open Patient Profile', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showSuccessOverlay = false;
                    _patient = p; // Switch to Known Caller view
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: Colors.transparent,
                  child: const Center(
                    child: Text('Done', style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientInfoCard() {
    final p = _patient!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          _infoRow('Health Issue', p.healthIssue.isNotEmpty ? p.healthIssue : 'Chronic Migraine'),
          const SizedBox(height: 12),
          _infoRow('Last Visit', '12 Apr 2024'),
          const SizedBox(height: 12),
          _infoRow('Last Update', '4 Days Ago'),
          const SizedBox(height: 12),
          _infoRow('Medicine', p.medication.isNotEmpty ? p.medication : 'Natrum Mur 200'),
          const SizedBox(height: 12),
          _infoRow('Next Follow-up', 'Tomorrow'),
          const SizedBox(height: 12),
          _infoRow('Consultation Valid Till', '10 May 2024', isBoldGreen: true),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => PatientDetailScreen(patient: p)),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'View Full Profile',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBoldGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          value.isNotEmpty ? value : '—',
          style: TextStyle(
            color: isBoldGreen ? const Color(0xFF166534) : const Color(0xFF1E293B),
            fontSize: 12,
            fontWeight: isBoldGreen ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls(CallProvider cp) {
    if (cp.state == CallState.ringing) {
      if (_isUnknown) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionColumn(Icons.close, const Color(0xFFEF4444), 'Ignore', cp.rejectCall),
            _actionColumn(Icons.check, const Color(0xFF22C55E), 'Add as Patient', cp.answerCall), // Simulate answer and add
          ],
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _circleButton(Icons.call_end, const Color(0xFFEF4444), cp.rejectCall),
            _circleButton(Icons.phone, const Color(0xFF22C55E), cp.answerCall),
          ],
        );
      }
    } else {
      // Active call
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconButton(cp.isMuted ? Icons.mic_off : Icons.mic, cp.isMuted ? 'Muted' : 'Mute', () => cp.toggleMute(), isActive: cp.isMuted),
              _iconButton(Icons.dialpad, 'Keypad', () {
                setState(() {
                  _showDialpad = !_showDialpad;
                  if (!_showDialpad) _dialpadBuffer = '';
                });
              }, isActive: _showDialpad),
              _iconButton(Icons.auto_awesome, 'AI Notes', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AILiveCallScreen(patient: _patient)),
                );
              }),
              _iconButton(cp.isSpeakerOn ? Icons.volume_up : Icons.volume_down, cp.isSpeakerOn ? 'Speaker On' : 'Speaker', () => cp.toggleSpeaker(), isActive: cp.isSpeakerOn),
            ],
          ),
          const SizedBox(height: 24),
          _circleButton(Icons.call_end, const Color(0xFFEF4444), cp.hangupCall),
        ],
      );
    }
  }

  Widget _actionColumn(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(
      children: [
        _circleButton(icon, color, onTap),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        )
      ],
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? AppColors.primary : Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          )
        ],
      ),
    );
  }

  Widget _buildDialpadHeader() {
    return Column(
      children: [
        Text(
          _dialpadBuffer.isEmpty ? 'Dialpad' : _dialpadBuffer,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Active Call with $_displayName',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDialpad(CallProvider cp) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: row.map((key) => _buildDialKey(key, cp)).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDialKey(String key, CallProvider cp) {
    return GestureDetector(
      onTapDown: (_) {
        cp.playDtmf(key);
        setState(() {
          _dialpadBuffer += key;
        });
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
