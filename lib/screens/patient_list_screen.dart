import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/providers/patient_provider.dart';
import '../core/providers/call_provider.dart';
import '../core/models/patient.dart';
import 'add_edit_patient_screen.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Group patients alphabetically
  Map<String, List<Patient>> _groupByLetter(List<Patient> patients) {
    final Map<String, List<Patient>> grouped = {};
    for (final p in patients) {
      final letter = p.name.trim().isEmpty
          ? '#'
          : p.name.trim()[0].toUpperCase();
      grouped.putIfAbsent(letter, () => []).add(p);
    }
    // Sort keys alphabetically
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  List<Patient> _applySearch(List<Patient> patients) {
    if (_query.isEmpty) return patients;
    final q = _query.toLowerCase();
    return patients
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.phoneNumber.contains(q))
        .toList();
  }

  Future<void> _makeCall(BuildContext context, String number) async {
    try {
      await context.read<CallProvider>().makeCall(number);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS-style grey bg
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        final count = provider.allPatients.length;
        return Container(
          color: const Color(0xFFF2F2F7),
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patients',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '$count contacts',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              // Add button
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AddEditPatientScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A56DB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            prefixIcon: const Icon(Icons.search,
                color: Color(0xFF8E8E93), size: 18),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    child: const Icon(Icons.cancel,
                        color: Color(0xFF8E8E93), size: 18),
                  )
                : null,
            hintText: 'Search',
            hintStyle: const TextStyle(
                color: Color(0xFF8E8E93), fontSize: 15),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Patient List ───────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = _applySearch(provider.allPatients);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_search_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _query.isEmpty ? 'No patients added yet' : 'No results for "$_query"',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500),
                ),
                if (_query.isEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddEditPatientScreen()),
                    ),
                    child: const Text(
                      'Add your first patient',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1A56DB),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Build alphabetical sections
        final grouped = _groupByLetter(filtered);
        final sections = grouped.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: sections.fold<int>(
              0, (sum, e) => sum + 1 + e.value.length), // header + rows
          itemBuilder: (context, flatIndex) {
            // Flatten sections into a flat index
            int current = 0;
            for (final section in sections) {
              if (flatIndex == current) {
                // Section header
                return _buildSectionHeader(section.key);
              }
              current++;
              for (final patient in section.value) {
                if (flatIndex == current) {
                  final isLast =
                      current == (current - 1 + section.value.length);
                  return _buildContactRow(
                    context,
                    patient,
                    isLast: patient == section.value.last,
                    isFirst: patient == section.value.first,
                  );
                }
                current++;
              }
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String letter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context,
    Patient patient, {
    required bool isFirst,
    required bool isLast,
  }) {
    final statusColor = _statusColor(patient.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(14) : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => PatientDetailScreen(patient: patient)),
            ),
            onLongPress: () => _showOptions(context, patient),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(14) : Radius.zero,
              bottom: isLast ? const Radius.circular(14) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      _ContactAvatar(name: patient.name),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Name + number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patient.phoneNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Call button
                  GestureDetector(
                    onTap: () => _makeCall(context, patient.phoneNumber),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Color(0xFF34C759),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider (not on last item)
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(left: 72),
              child: Divider(height: 1, color: Color(0xFFF2F2F7)),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, Patient patient) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Patient header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ContactAvatar(name: patient.name, size: 60, fontSize: 24),
                  const SizedBox(height: 10),
                  Text(patient.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 2),
                  Text(patient.phoneNumber,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Action list
            _optionSheet([
              _SheetOption(
                icon: Icons.call,
                iconColor: const Color(0xFF34C759),
                label: 'Call',
                onTap: () {
                  Navigator.pop(ctx);
                  _makeCall(context, patient.phoneNumber);
                },
              ),
              _SheetOption(
                icon: Icons.person_outline,
                iconColor: AppColors.primary,
                label: 'View Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PatientDetailScreen(patient: patient)));
                },
              ),
              _SheetOption(
                icon: Icons.edit_outlined,
                iconColor: const Color(0xFFFF9F0A),
                label: 'Edit Patient',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddEditPatientScreen(patient: patient)));
                },
              ),
              _SheetOption(
                icon: Icons.history,
                iconColor: Colors.orange,
                label: 'Clear Clinical History',
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmClearHistory(context, patient);
                },
              ),
              _SheetOption(
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFFF3B30),
                label: 'Delete Patient',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, patient);
                },
              ),
            ]),
            const SizedBox(height: 8),
            // Cancel
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A56DB))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionSheet(List<_SheetOption> options) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: options.asMap().entries.map((e) {
          final opt = e.value;
          final isLast = e.key == options.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: opt.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(opt.icon, color: opt.iconColor, size: 18),
                ),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: opt.isDestructive
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF1C1C1E),
                  ),
                ),
                onTap: opt.onTap,
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.only(left: 62),
                  child: Divider(height: 1, color: Color(0xFFF2F2F7)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History?'),
        content: Text(
            'This will delete all timeline records and AI notes for ${patient.name}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await context.read<PatientProvider>().clearTimeline(patient.phoneNumber);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('History cleared for ${patient.name}')),
                  );
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Patient?'),
        content: Text(
            'Are you sure you want to delete ${patient.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await context.read<PatientProvider>().deletePatient(patient.phoneNumber);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${patient.name} deleted'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'recovering': return const Color(0xFF34C759);
      case 'no_improvement': return const Color(0xFFFF3B30);
      default: return const Color(0xFFFF9F0A);
    }
  }
}

// ── Contact Avatar ─────────────────────────────────────────────────────────────
class _ContactAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;

  const _ContactAvatar({
    required this.name,
    this.size = 44,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF007AFF), // Blue
      Color(0xFF34C759), // Green
      Color(0xFFFF9F0A), // Orange
      Color(0xFFAF52DE), // Purple
      Color(0xFFFF2D55), // Pink
      Color(0xFF5AC8FA), // Light blue
      Color(0xFFFF3B30), // Red
      Color(0xFF4CD964), // Mint
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[idx],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet option model ──────────────────────────────────────────────────
class _SheetOption {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}
