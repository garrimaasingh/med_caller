import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/providers/call_provider.dart';
import '../core/providers/patient_provider.dart';
import '../core/models/patient.dart';
import '../core/app_design.dart';
import '../widgets/ai_quick_summary_card.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<CallLogEntry> _logs = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  String _filter = 'all'; // all | patients | missed
  bool _showDialpad = false;
  String _dialedNumber = '';
  Patient? _matchedPatient;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final status = await Permission.phone.request();

    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
      return;
    }

    final entries = await CallLog.get();
    setState(() {
      _logs = entries.toList();
      _isLoading = false;
    });
  }

  String _normalize(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  List<CallLogEntry> get _filtered {
    final patients = context.read<PatientProvider>().allPatients;
    final patientNumbers = patients.map((p) => _normalize(p.phoneNumber)).toSet();

    switch (_filter) {
      case 'all':
        // Show every call log entry from the device
        return _logs.where((e) => e.number != null && e.number!.isNotEmpty).toList();
      case 'patients':
        // Only calls from known patients
        return _logs.where((e) => e.number != null && patientNumbers.contains(_normalize(e.number))).toList();
      case 'missed':
        // All missed calls (not just patient ones)
        return _logs.where((e) => e.callType == CallType.missed).toList();
      default:
        return _logs.where((e) => e.number != null && e.number!.isNotEmpty).toList();
    }
  }

  Future<void> _call(String number) async {
    try {
      await context.read<CallProvider>().makeCall(number);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  void _onKeyPressed(String value) {
    setState(() => _dialedNumber += value);
    _lookupPatient();
  }

  void _onDelete() {
    if (_dialedNumber.isNotEmpty) {
      setState(() => _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1));
      _lookupPatient();
    }
  }

  Future<Patient?> _lookupPatient() async {
    if (_dialedNumber.length < 5) {
      setState(() => _matchedPatient = null);
      return null;
    }
    final p = await context.read<PatientProvider>().findByPhoneNumber(_dialedNumber);
    if (mounted) setState(() => _matchedPatient = p);
    return p;
  }

  String _getEntryId(CallLogEntry entry) {
    try {
      return (entry as dynamic).id?.toString() ?? entry.timestamp?.toString() ?? 'unknown';
    } catch (e) {
      return entry.timestamp?.toString() ?? 'unknown';
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_filtered.map(_getEntryId));
    });
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _enterSelectionMode() {
    setState(() => _selectionMode = true);
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call Logs'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} selected logs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in _selectedIds) {
          await CallLog.deleteCallLog(id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${_selectedIds.length} logs')),
          );
        }
        _clearSelection();
        _loadLogs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete logs: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteLog(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call Log'),
        content: const Text('Are you sure you want to delete this call log?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CallLog.deleteCallLog(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log deleted')),
          );
        }
        _loadLogs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete log: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteHistoryForNumber(String? number) async {
    if (number == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: Text('Are you sure you want to delete ALL call logs for $number?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final logsToDelete = _logs.where((l) => l.number == number).toList();
        for (final log in logsToDelete) {
          final id = _getEntryId(log);
          if (id != 'unknown') {
            await CallLog.deleteCallLog(id);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${logsToDelete.length} logs for $number')),
          );
        }
        _loadLogs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear history: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('Are you sure you want to delete ALL call logs from your phone? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        for (final log in _logs) {
          final id = _getEntryId(log);
          if (id != 'unknown') {
            await CallLog.deleteCallLog(id);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All call logs cleared')),
          );
        }
        _loadLogs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear logs: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteMenu(CallLogEntry entry, String entryId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Log Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete this log'),
              onTap: () {
                Navigator.pop(context);
                _deleteLog(entryId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: Text('Delete all from ${entry.number ?? 'this number'}'),
              onTap: () {
                Navigator.pop(context);
                _deleteHistoryForNumber(entry.number);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rtl),
              title: const Text('Select multiple'),
              onTap: () {
                Navigator.pop(context);
                _toggleSelection(entryId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Phone permission required',
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _selectionMode
          ? AppBar(
              elevation: 2,
              backgroundColor: const Color(0xFF1A56DB),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _clearSelection,
                tooltip: 'Cancel Selection',
              ),
              title: Text(
                _selectedIds.isEmpty
                    ? 'Select Logs'
                    : '${_selectedIds.length} Selected',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                if (_selectedIds.length == _filtered.length)
                  TextButton(
                    onPressed: _deselectAll,
                    child: const Text('Deselect All', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  )
                else
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('Select All', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                if (_selectedIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: _deleteSelected,
                    tooltip: 'Delete Selected',
                  ),
              ],
            )
          : AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
              title: const Text('Call Logs',
                  style: TextStyle(
                      color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
              actions: [
                TextButton.icon(
                  onPressed: _enterSelectionMode,
                  icon: const Icon(Icons.checklist_rtl, color: Color(0xFF1A56DB), size: 18),
                  label: const Text('Select', style: TextStyle(color: Color(0xFF1A56DB), fontWeight: FontWeight.w600)),
                ),
                IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.redAccent),
                    onPressed: _clearAllLogs,
                    tooltip: 'Clear All Logs'),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              // Selection mode banner
              if (_selectionMode && _selectedIds.isNotEmpty)
                Container(
                  color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} of ${_filtered.length} selected',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: _deleteSelected,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All Calls', Icons.call),
                      const SizedBox(width: 8),
                      _filterChip('missed', 'Missed', Icons.call_missed),
                    ],
                  ),
                ),
              ),
              // List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'patients'
                                  ? 'No calls from saved patients'
                                  : _filter == 'missed'
                                      ? 'No missed calls'
                                      : 'No call history yet',
                              style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            if (_filter == 'patients') ...[
                              const SizedBox(height: 6),
                              Text(
                                'Switch to "All Calls" to see everything',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: Consumer<PatientProvider>(
                          builder: (context, provider, _) {
                            return ListView.builder(
                              itemCount: _filtered.length,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemBuilder: (context, index) {
                                  final entry = _filtered[index];
                                  final entryId = _getEntryId(entry);
                                  final patients = provider.allPatients;
                                  final entryNum = _normalize(entry.number);
                                  final patient = patients.cast<Patient?>().firstWhere(
                                    (p) => _normalize(p?.phoneNumber) == entryNum,
                                    orElse: () => null,
                                  );

                                  return Column(
                                    children: [
                                      _CallLogTile(
                                        entry: entry,
                                        patient: patient,
                                        isDark: isDark,
                                        isSelected: _selectedIds.contains(entryId),
                                        selectionMode: _selectionMode,
                                        onCall: () => _call(entry.number ?? ''),
                                        onTap: () {
                                          if (_selectionMode) {
                                            _toggleSelection(entryId);
                                          } else {
                                            _call(entry.number ?? '');
                                          }
                                        },
                                        onLongPress: () {
                                          if (!_selectionMode) {
                                            _showDeleteMenu(entry, entryId);
                                          } else {
                                            _toggleSelection(entryId);
                                          }
                                        },
                                      ),
                                    ],
                                  );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_showDialpad) _buildDialpadOverlay(isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showDialpad = !_showDialpad;
            if (!_showDialpad) _dialedNumber = '';
          });
        },
        backgroundColor: const Color(0xFF1A56DB),
        child: Icon(_showDialpad ? Icons.close : Icons.dialpad, color: Colors.white),
      ),
    );
  }

  Widget _buildDialpadOverlay(bool isDark) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100), // Height for bottom nav
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_matchedPatient != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.person, color: Color(0xFF1A56DB), size: 16),
                  const SizedBox(width: 8),
                  Text(_matchedPatient!.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ]),
              ),
            Text(
              _dialedNumber.isEmpty ? 'Type Number' : _dialedNumber,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: isDark ? Colors.white : const Color(0xFF1E293B), letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            _keyRow(['1', '2', '3']),
            _keyRow(['4', '5', '6']),
            _keyRow(['7', '8', '9']),
            _keyRow(['*', '0', '#']),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 48), // Spacer
                GestureDetector(
                  onTap: () => _call(_dialedNumber),
                  child: Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: Color(0xFF1A56DB), shape: BoxShape.circle),
                    child: const Icon(Icons.call, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: _onDelete, icon: const Icon(Icons.backspace_outlined, color: Colors.grey))
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyRow(List<String> digits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map((d) => _keyButton(d)).toList(),
      ),
    );
  }

  Widget _keyButton(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPressed(digit),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: Center(child: Text(digit, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400))),
      ),
    );
  }

  Widget _filterChip(String value, String label, [IconData? icon]) {
    final selected = _filter == value;
    final chipColor = value == 'missed' ? Colors.red : const Color(0xFF1A56DB);
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : Theme.of(context).dividerColor,
          ),
          boxShadow: selected
              ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : Theme.of(context).hintColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Theme.of(context).hintColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Call log tile ─────────────────────────────────────────────────────────────
class _CallLogTile extends StatelessWidget {
  final CallLogEntry entry;
  final Patient? patient;
  final bool isDark;
  final VoidCallback onCall;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CallLogTile({
    required this.entry,
    this.patient,
    required this.isDark,
    required this.onCall,
    this.isSelected = false,
    this.selectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final typeData = _typeData(entry.callType);
    final name = entry.name?.isNotEmpty == true ? entry.name! : entry.number ?? 'Unknown';
    final time =
        entry.timestamp != null
            ? _formatTime(entry.timestamp!)
            : '';
    final duration =
        entry.callType == CallType.missed
            ? ''
            : _formatDuration(entry.duration ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1A56DB)
                    : typeData.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Icon(typeData.icon, color: typeData.color, size: 20),
            ),
            if (selectionMode && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                patient?.name ?? (entry.name?.isNotEmpty == true ? entry.name! : entry.number ?? 'Unknown'),
                style: TextStyle(
                  fontWeight: entry.callType == CallType.missed || patient != null
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: entry.callType == CallType.missed
                      ? Colors.red
                      : (patient != null ? AppColors.textDark : null),
                ),
              ),
            ),
            if (patient != null)
              _buildStatusPill(patient!.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.name?.isNotEmpty == true)
              GestureDetector(
                onLongPress: onLongPress,
                child: Text(
                  entry.number ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            Row(
              children: [
                Text(
                  typeData.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: typeData.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (duration.isNotEmpty) ...[
                  const Text(' · ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  Text(
                    duration,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
                const Text(' · ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text(
                  time,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.call, color: Color(0xFF1A56DB), size: 22),
          onPressed: entry.number != null ? onCall : null,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
        selected: isSelected,
        selectedTileColor: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color textColor;
    Color bgColor;
    String label;

    switch (status) {
      case 'recovering':
        textColor = const Color(0xFF16A34A);
        bgColor = const Color(0xFFDCFCE7);
        label = 'Recovered';
        break;
      case 'no_improvement':
        textColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
        label = 'No Improvement';
        break;
      default:
        textColor = const Color(0xFFB45309);
        bgColor = const Color(0xFFFEF3C7);
        label = 'Improving';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _TypeData _typeData(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return _TypeData(
          Icons.call_received, const Color(0xFF10B981), 'Incoming');
      case CallType.outgoing:
        return _TypeData(
          Icons.call_made, const Color(0xFF1A56DB), 'Outgoing');
      case CallType.missed:
        return _TypeData(
          Icons.call_missed, Colors.red, 'Missed');
      case CallType.rejected:
        return _TypeData(
          Icons.call_end, Colors.orange, 'Declined');
      default:
        return _TypeData(Icons.call, Colors.grey, 'Unknown');
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    } else if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat('MMM d, y').format(dt);
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _TypeData {
  final IconData icon;
  final Color color;
  final String label;
  _TypeData(this.icon, this.color, this.label);
}
