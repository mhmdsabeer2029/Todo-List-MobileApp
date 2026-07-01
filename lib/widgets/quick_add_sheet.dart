import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../store/task_store.dart';
import '../store/project_store.dart';
import '../utils/nlp_parser.dart';
import '../utils/groq_service.dart';
import '../utils/voice_service_platform.dart';
import '../constants/theme.dart';

class QuickAddSheet extends StatefulWidget {
  final String? initialProjectId;

  const QuickAddSheet({super.key, this.initialProjectId});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  ParsedTask? _parsed;
  bool _submitting = false;

  // Set when the user explicitly picks a date via the calendar toolbar
  // button. This always wins over whatever the NLP/Groq parser infers from
  // the text, since the local NlpParser can only recognise relative phrases
  // like "tomorrow" or "next monday" — not an arbitrary picked date.
  DateTime? _pickedDueDate;

  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final LabelStore _labelStore = LabelStore();
  final VoiceService _voiceService = VoiceService();
  final GroqService _groqService = GroqService();
  bool _voiceReady = false;
  bool _voiceLoading = false;
  String _voiceHint = 'Voice input';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      final available = await _voiceService.initialize();
      if (mounted) {
        setState(() {
          _voiceReady = available;
          _voiceHint = available ? 'Hold to speak' : 'Voice unavailable';
        });
      }
    });
  }

  @override
  void dispose() {
    _voiceService.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChange() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _parsed = null);
      return;
    }
    setState(() => _parsed = NlpParser.parse(text));
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);

    try {
      final parsed = await _parseWithGroq(text);
      // An explicitly picked date (via the calendar toolbar button) always
      // wins over whatever the text parser inferred.
      final dueDate = _pickedDueDate != null
          ? DateFormat('yyyy-MM-dd').format(_pickedDueDate!)
          : parsed.dueDate;

      // Resolve project
      String? projectId = widget.initialProjectId;
      if (parsed.projectName != null) {
        final found = _projectStore.projects
            .where((p) => p.name.toLowerCase() == parsed.projectName!.toLowerCase())
            .firstOrNull;
        projectId = found?.id;
        if (found == null) {
          final newP = await _projectStore.addProject(name: parsed.projectName!);
          projectId = newP.id;
        }
      }

      // Resolve labels
      final labelIds = <String>[];
      for (final name in parsed.labelNames) {
        final found = _labelStore.labels
            .where((l) => l.name.toLowerCase() == name.toLowerCase())
            .firstOrNull;
        if (found != null) {
          labelIds.add(found.id);
        } else {
          final newL = await _labelStore.addLabel(name: name);
          labelIds.add(newL.id);
        }
      }

      await _taskStore.addTask(
        title: parsed.cleanTitle.isEmpty ? text : parsed.cleanTitle,
        projectId: projectId,
        priority: parsed.priority,
        dueDate: dueDate,
        dueTime: parsed.dueTime,
        isRecurring: parsed.isRecurring,
        recurrenceRule: parsed.recurrenceRule,
        labelIds: labelIds,
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<ParsedTask> _parseWithGroq(String text) async {
    if (text.isEmpty) return NlpParser.parse(text);
    try {
      final intent = await _groqService.parseTaskIntent(
        text,
        existingProjects: _projectStore.activeProjects.map((p) => p.name).toList(),
        existingLabels: _labelStore.labels.map((l) => l.name).toList(),
      );
      if (intent.title.isNotEmpty) {
        final parsed = intent.toParsedTask();
        if (parsed.cleanTitle.isNotEmpty) return parsed;
      }
    } catch (_) {}
    return NlpParser.parse(text);
  }

  bool _isRecording = false;
  String _textBeforeVoice = '';

  /// Starts live, continuous dictation. Text appears in the field instantly
  /// as the user speaks - no waiting for a "final" result.
  Future<void> _startVoice() async {
    if (!_voiceReady || _isRecording) return;

    _textBeforeVoice = _controller.text;
    setState(() {
      _isRecording = true;
      _voiceHint = 'Listening...';
    });

    _voiceService.onPartial = (text, isFinal) {
      if (!mounted) return;
      final merged = _mergeVoiceText(_textBeforeVoice, text);
      _controller.text = merged;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    };
    _voiceService.onError = (message) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _voiceHint = 'Voice failed';
      });
    };
    _voiceService.onDone = () async {
      if (!mounted) return;
      setState(() => _isRecording = false);
      final finalText = _controller.text.trim();
      if (finalText.isNotEmpty) {
        setState(() => _voiceLoading = true);
        try {
          final parsed = await _parseWithGroq(finalText);
          if (mounted) {
            setState(() {
              _parsed = parsed;
              _voiceHint = 'Parsed from voice';
            });
          }
        } finally {
          if (mounted) setState(() => _voiceLoading = false);
        }
      }
    };

    await _voiceService.startListening(localeId: 'ar-EG');
  }

  /// Stops dictation immediately, e.g. on release of a press-and-hold mic button.
  Future<void> _stopVoice() async {
    if (!_isRecording) return;
    await _voiceService.stop();
  }

  String _mergeVoiceText(String before, String spoken) {
    final trimmedBefore = before.trim();
    if (spoken.isEmpty) return trimmedBefore;
    if (trimmedBefore.isEmpty) return spoken;
    return '$trimmedBefore $spoken';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? kDarkSurface : kLightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? kDarkBorder : kLightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Preview chips (NLP result)
              if (_parsed != null && _controller.text.isNotEmpty)
                _NlpPreviewRow(parsed: _parsed!),

              if (_pickedDueDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PreviewChip(
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat('MMM d').format(_pickedDueDate!),
                        color: kP3Blue,
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pickedDueDate = null),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.close, size: 14, color: kTextMuted),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: 2),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kP1Red),
                      ),
                      const SizedBox(width: 6),
                      Text('Listening… release to stop',
                          style: TextStyle(fontSize: 11, color: kP1Red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // Input row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace8),
                child: Row(
                  children: [
                    // Priority dot
                    GestureDetector(
                      onTap: _cyclePriority,
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: kSpace8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: priorityColor(_parsed?.priority ?? 4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? kDarkBorder : kLightBorder,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'ضيف task… مثل: "أنا عايز أعمل شغل بكره على 3 الظهر #شغل p1" أو "Call Alex tomorrow at 3pm"',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: theme.textTheme.bodyLarge,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          maxLines: 1,
                          minLines: 1,
                        ),
                      ),
                    ),

                    // Voice button — press and hold to talk, release to stop.
                    // Text streams live into the field while held.
                    _voiceLoading
                        ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                        : GestureDetector(
                            onLongPressStart: (_) => _startVoice(),
                            onLongPressEnd: (_) => _stopVoice(),
                            onLongPressCancel: _stopVoice,
                            onTap: () {
                              if (_isRecording) {
                                _stopVoice();
                              } else {
                                _startVoice();
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording ? kP1Red.withOpacity(0.12) : Colors.transparent,
                              ),
                              child: Icon(
                                _isRecording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                                color: !_voiceReady
                                    ? kTextMuted
                                    : (_isRecording ? kP1Red : kPrimary),
                                size: 24,
                              ),
                            ),
                          ),

                    // Submit button
                    _submitting
                        ? const SizedBox(width: 36, height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            onPressed: _submit,
                            icon: const Icon(Icons.send_rounded),
                            color: kPrimary,
                            iconSize: 26,
                          ),
                  ],
                ),
              ),

              // Toolbar: date, project, priority
              _Toolbar(
                parsed: _parsed,
                onDatePick: _pickDate,
                onProjectPick: _pickProject,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cyclePriority() {
    // Not implemented inline — user can type p1, p2, etc.
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _pickedDueDate = picked);
    }
  }

  Future<void> _pickProject() async {
    final projects = _projectStore.activeProjects;
    final picked = await showModalBottomSheet<Project>(
      context: context,
      builder: (ctx) => _ProjectPickerSheet(projects: projects),
    );
    if (picked != null) {
      final current = _controller.text.trim();
      final withoutProject = current.replaceAll(RegExp(r'#\w+'), '').trim();
      _controller.text = '$withoutProject #${picked.name}'.trim();
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }
}

class _NlpPreviewRow extends StatelessWidget {
  final ParsedTask parsed;

  const _NlpPreviewRow({required this.parsed});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (parsed.dueDate != null) {
      chips.add(_PreviewChip(
        icon: Icons.calendar_today_outlined,
        label: _formatDate(parsed.dueDate!),
        color: kP3Blue,
      ));
    }
    if (parsed.dueTime != null) {
      chips.add(_PreviewChip(
        icon: Icons.access_time,
        label: parsed.dueTime!,
        color: kP3Blue,
      ));
    }
    if (parsed.projectName != null) {
      chips.add(_PreviewChip(
        icon: Icons.folder_outlined,
        label: parsed.projectName!,
        color: kTextMuted,
      ));
    }
    for (final l in parsed.labelNames) {
      chips.add(_PreviewChip(icon: Icons.label_outline, label: l, color: kTextMuted));
    }
    if (parsed.priority < 4) {
      chips.add(_PreviewChip(
        icon: Icons.flag_outlined,
        label: 'P${parsed.priority}',
        color: priorityColor(parsed.priority),
      ));
    }
    if (parsed.isRecurring) {
      chips.add(const _PreviewChip(icon: Icons.repeat, label: 'Recurring', color: kP3Blue));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: 4),
      child: Row(children: chips),
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      final today = DateTime.now();
      if (d.year == today.year && d.month == today.month && d.day == today.day) return 'Today';
      final tomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
      if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) return 'Tomorrow';
      return DateFormat('MMM d').format(d);
    } catch (_) {
      return date;
    }
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PreviewChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final ParsedTask? parsed;
  final VoidCallback onDatePick;
  final VoidCallback onProjectPick;

  const _Toolbar({this.parsed, required this.onDatePick, required this.onProjectPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? kDarkBorder : kLightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _ToolbarBtn(icon: Icons.calendar_today_outlined, tooltip: 'Due date', onTap: onDatePick),
          _ToolbarBtn(icon: Icons.folder_outlined, tooltip: 'Project', onTap: onProjectPick),
          _ToolbarBtn(
            icon: Icons.flag_outlined,
            tooltip: 'Priority',
            color: parsed != null ? priorityColor(parsed!.priority) : null,
            onTap: () {},
          ),
          _ToolbarBtn(icon: Icons.label_outline, tooltip: 'Labels', onTap: () {}),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ToolbarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color ?? kTextMuted),
      tooltip: tooltip,
      padding: const EdgeInsets.all(12),
    );
  }
}

class _ProjectPickerSheet extends StatelessWidget {
  final List<Project> projects;

  const _ProjectPickerSheet({required this.projects});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(kSpace16),
            child: Text('Select Project',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...projects.map((p) => ListTile(
            leading: Text(p.emoji, style: const TextStyle(fontSize: 20)),
            title: Text(p.name),
            onTap: () => Navigator.pop(context, p),
          )),
          const SizedBox(height: kSpace8),
        ],
      ),
    );
  }
}

// Convenience function
Future<void> showQuickAdd(BuildContext context, {String? projectId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuickAddSheet(initialProjectId: projectId),
  );
}
