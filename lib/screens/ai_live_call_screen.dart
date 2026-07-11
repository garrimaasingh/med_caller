import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_design.dart';
import '../core/models/patient.dart';
import '../core/services/speech_service.dart';
import '../core/providers/ai_settings.dart';
import '../core/providers/patient_provider.dart';

class AILiveCallScreen extends StatefulWidget {
  final Patient? patient;
  const AILiveCallScreen({super.key, this.patient});

  @override
  State<AILiveCallScreen> createState() => _AILiveCallScreenState();
}

class _AILiveCallScreenState extends State<AILiveCallScreen> with TickerProviderStateMixin {
  late SpeechAIService _speechAI;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  String _activeTab = 'transcript';
  final _textController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AiSettingsProvider>();
    _speechAI = SpeechAIService(settings);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _speechAI.addListener(_onUpdate);
    _speechAI.initialize();
    _startDurationTimer();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration = Duration(seconds: timer.tick));
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _onUpdate() {
    if (mounted) setState(() {});
    if (_speechAI.hasResult && _activeTab == 'transcript') {
      setState(() => _activeTab = 'summary');
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _speechAI.removeListener(_onUpdate);
    _speechAI.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_speechAI.isListening) {
      await _speechAI.stopListeningAndGenerate();
    } else {
      await _speechAI.startListening();
    }
  }

  Future<void> _generateFromTypedText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await _speechAI.generateFromText(text);
    setState(() => _activeTab = 'summary');
  }

  Future<void> _saveToPatientRecord() async {
    final result = _speechAI.latestResult;
    if (result == null || widget.patient == null) return;

    try {
      final now = DateTime.now();
      final updatedPatient = widget.patient!.copyWith(
        status: result.suggestedStatus,
        lastVisitDate: now,
        aiSummary: result.quickSummary.join('\n'),
      );

      await context.read<PatientProvider>().updatePatient(updatedPatient);
      
      // Also add to real-time timeline
      await context.read<PatientProvider>().addTimelineEvent(updatedPatient.phoneNumber, {
        'type': 'ai_consultation',
        'title': 'AI Consultation Note',
        'description': result.quickSummary.join('\n'),
        'condition': updatedPatient.status,
        'improvementPercent': result.improvementPercent,
        'detailed_notes': result.detailedNotes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ AI Summary saved to patient record locally'),
          backgroundColor: AppColors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildPatientSection(),
            _buildTabs(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildTabContent(),
              ),
            ),
            if (_speechAI.lastError != null) _buildErrorBanner(),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('AI Call Notes', style: AppTextStyles.screenTitle),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              'Call Duration: ${_formatDuration(_callDuration)}',
              style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSection() {
    final p = widget.patient;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Call with ${p?.name ?? "Unknown"}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  '10 May 2024, 10:30 AM',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final p = widget.patient;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: p != null 
          ? PatientAvatar(name: p.name, size: 56, fontSize: 18)
          : const Icon(Icons.person, color: Colors.grey),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _tabItem('transcript', 'Transcript'),
          _tabItem('summary', 'Summary'),
          _tabItem('history', 'History'),
        ],
      ),
    );
  }

  Widget _tabItem(String value, String label) {
    final isSelected = _activeTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = value),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.green : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 2,
              color: isSelected ? AppColors.green : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'transcript':
        return _buildTranscriptView();
      case 'summary':
        return _buildSummaryView();
      case 'history':
        return _buildHistoryView();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTranscriptView() {
    final transcript = _speechAI.fullTranscript;
    return Column(
      children: [
        Expanded(
          child: transcript.isEmpty && _speechAI.currentWords.isEmpty
            ? _buildEmptyTranscription()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFormattedTranscript(transcript),
                  if (_speechAI.currentWords.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _speechAI.currentWords,
                        style: TextStyle(color: AppColors.textLight.withOpacity(0.5), fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildFormattedTranscript(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final isDoctor = line.toLowerCase().startsWith('doctor:');
        final isPatient = line.toLowerCase().startsWith('${widget.patient?.name.toLowerCase()}:') || 
                          (!isDoctor && line.contains(':'));
        
        final parts = line.split(':');
        final name = parts.length > 1 ? parts[0] : '';
        final content = parts.length > 1 ? parts.sublist(1).join(':') : line;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, height: 1.5),
              children: [
                if (name.isNotEmpty)
                  TextSpan(
                    text: '$name: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDoctor ? AppColors.primary : const Color(0xFF6366F1),
                    ),
                  ),
                TextSpan(
                  text: content,
                  style: const TextStyle(color: AppColors.textDark),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyTranscription() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 48, color: AppColors.textHint.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No transcript yet', style: TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 4),
          const Text('Speak or type to start', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type consultation notes...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => _generateFromTypedText(),
            ),
          ),
          IconButton(
            icon: Icon(
              _speechAI.isListening ? Icons.stop_circle : Icons.mic_none,
              color: _speechAI.isListening ? AppColors.red : AppColors.primary,
            ),
            onPressed: _toggleListening,
          ),
          if (_textController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.green),
              onPressed: _generateFromTypedText,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_speechAI.isProcessing) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final result = _speechAI.latestResult;
    if (result == null) {
      return const Center(child: Text('No summary generated yet'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('AI Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.green)),
        const SizedBox(height: 16),
        ...result.quickSummary.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: AppColors.green, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.4),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),
        const Text('Suggested Status Update', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.yellowLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.yellowBorder.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppColors.yellow, size: 16),
              const SizedBox(width: 12),
              Text(
                '${statusLabel(result.suggestedStatus)} (${result.improvementPercent}%)',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    final result = _speechAI.latestResult;
    if (result == null) return const Center(child: Text('Generate a summary first'));

    final notes = result.detailedNotes;
    final displayOrder = [
      'Symptoms', 'Medicines', 'Condition', 'Lifestyle',
      'Sleep Issues', 'Emotional State', 'Treatment Update', 'Follow-up',
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _historySection('AI Analysis', {
          for (final key in displayOrder)
            key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}'): notes[key] ?? '',
        }),
        _historySection('Timeline', {
          'Entry': result.timelineEntry,
        }),
        _historySection('Status', {
          'Suggested Status': result.suggestedStatus,
          'Improvement': '${result.improvementPercent}%',
        }),
      ],
    );
  }

  Widget _historySection(String title, Map<String, dynamic> fields) {
    final validFields = fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty && e.value.toString().toLowerCase() != 'null').toList();
    if (validFields.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 12),
        ...validFields.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLight))),
              Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.4))),
            ],
          ),
        )),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.all(12),
      child: Text(_speechAI.lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
    );
  }

  Widget _buildFooterActions() {
    final result = _speechAI.latestResult;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Edit & Save', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: result != null ? _saveToPatientRecord : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Save to Record', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
