import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/patient_provider.dart';
import '../../core/theme.dart';
import '../../core/models/patient.dart';
import '../../core/utils/call_utils.dart';

class CallOverlay extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onDismiss;

  const CallOverlay({super.key, required this.phoneNumber, required this.onDismiss});

  static void show(BuildContext context, String phoneNumber) {
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => CallOverlay(
        phoneNumber: phoneNumber,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  late Future<Patient?> _patientFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
    
    // Future should be initialized here to prevent re-fetching on rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _patientFuture = context.read<PatientProvider>().findByPhoneNumber(widget.phoneNumber);
      });
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If _patientFuture isn't set yet (first frame), we can use a dummy future or just null
    Future<Patient?> futureToUse;
    try {
      futureToUse = _patientFuture;
    } catch (_) {
      futureToUse = Future.value(null);
    }

    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FutureBuilder<Patient?>(
            future: futureToUse,
            builder: (context, snapshot) {
              final patient = snapshot.connectionState == ConnectionState.waiting ? null : snapshot.data;
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_in_talk, color: AppTheme.accentGreen),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Incoming Call...",
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    patient?.name ?? widget.phoneNumber,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _dismiss,
                              icon: const Icon(Icons.close),
                            )
                          ],
                        ),
                        if (patient != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          _InfoRow(icon: Icons.local_hospital, title: "Issue", value: patient.healthIssue),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.medication, title: "Meds", value: patient.medication),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.note, title: "Notes", value: patient.notes),
                        ],
                        if (snapshot.connectionState == ConnectionState.waiting) ...[
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 20),
                             child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                           ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallActionBtn(
                              icon: Icons.call_end,
                              color: AppTheme.dangerRed,
                              label: "Decline",
                              onTap: _dismiss,
                            ),
                            _CallActionBtn(
                              icon: Icons.call,
                              color: AppTheme.accentGreen,
                              label: "Accept",
                              onTap: () {
                                _dismiss();
                                CallUtils.makeCall(context, widget.phoneNumber);
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        )
      ],
    );
  }
}
