import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/providers/patient_provider.dart';
import '../core/models/patient.dart';
import 'ai_live_call_screen.dart';

class AINotesScreen extends StatefulWidget {
  const AINotesScreen({super.key});

  @override
  State<AINotesScreen> createState() => _AINotesScreenState();
}

class _AINotesScreenState extends State<AINotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _recentFilter = 'all'; // all | recent | missed

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark bg for AI feel
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildPullIndicator(),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    _buildQuickTips(),
                    const SizedBox(height: 4),
                    Expanded(child: _buildPatientList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPullIndicator() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // AI Icon with animated glow
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Notes',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                    Text('AI-powered consultation recorder',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6))),
                  ],
                ),
              ),
              // Info button
              GestureDetector(
                onTap: () => _showHelpSheet(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.info_outline,
                      color: Colors.white.withOpacity(0.8), size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Feature pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _featurePill(Icons.mic, 'Voice Record'),
                const SizedBox(width: 8),
                _featurePill(Icons.summarize_outlined, 'Auto Summary'),
                const SizedBox(width: 8),
                _featurePill(Icons.history_edu, 'Case History'),
                const SizedBox(width: 8),
                _featurePill(Icons.psychology, 'AI Analysis'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 13),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => context.read<PatientProvider>().setSearchQuery(v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search,
                color: Color(0xFF94A3B8), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      context.read<PatientProvider>().setSearchQuery('');
                      setState(() {});
                    },
                    child: const Icon(Icons.close,
                        color: Color(0xFF94A3B8), size: 18),
                  )
                : null,
            hintText: 'Search patient for AI consultation...',
            hintStyle: const TextStyle(
                color: Color(0xFF94A3B8), fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.tips_and_updates_outlined,
                color: Color(0xFF6366F1), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tap a patient to start an AI-powered consultation session',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4338CA),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        final patients = provider.filteredPatients;

        if (patients.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 48, color: Color(0xFF6366F1)),
                ),
                const SizedBox(height: 20),
                const Text('No patients found',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                const Text('Add patients first to begin AI consultations',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${patients.length} patients',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B))),
                  const Text('Hold to view options',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: patients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = patients[index];
                  return _AIPatientTile(
                    patient: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AILiveCallScreen(patient: p),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                SizedBox(width: 10),
                Text('How AI Notes Works',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _helpItem('1', 'Select a patient from the list below',
                Icons.person_outline),
            _helpItem('2', 'Tap the microphone to start recording your consultation',
                Icons.mic_none),
            _helpItem('3', 'AI will transcribe and summarize the session automatically',
                Icons.summarize_outlined),
            _helpItem('4', 'Review, edit, and save the clinical notes to the patient\'s timeline',
                Icons.save_outlined),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Got it!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(String step, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF475569), height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Patient Tile ───────────────────────────────────────────────────────────
class _AIPatientTile extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;

  const _AIPatientTile({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(patient.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  PatientAvatar(name: patient.name, size: 48, fontSize: 18),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 3),
                    Text(patient.phoneNumber,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    if (patient.healthIssue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(patient.healthIssue,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              // Start AI button
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'recovering': return const Color(0xFF16A34A);
      case 'no_improvement': return const Color(0xFFDC2626);
      default: return const Color(0xFFCA8A04);
    }
  }
}
