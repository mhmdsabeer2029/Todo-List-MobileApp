import 'package:flutter/material.dart';
import '../../store/project_store.dart';
import '../../constants/theme.dart';

const _kColors = [
  '#DC4C3E', '#4073FF', '#058527', '#EB8909', '#D1453B',
  '#8C8C8C', '#7C3AED', '#DB2777', '#0891B2', '#059669',
];

const _kEmojis = [
  '📋', '🎯', '💼', '🏠', '🌟', '📚', '🏋️', '🎨',
  '💡', '🚀', '🎵', '🏃', '🍕', '✈️', '💻', '🌿',
];

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameCtrl = TextEditingController();
  String _selectedColor = '#4073FF';
  String _selectedEmoji = '📋';
  bool _saving = false;

  final ProjectStore _projectStore = ProjectStore();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final project = await _projectStore.addProject(
        name: name,
        color: _selectedColor,
        emoji: _selectedEmoji,
      );
      if (mounted) {
        Navigator.pop(context, project);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Create', style: TextStyle(color: kPrimary)),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpace16),
        children: [
          // Preview
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _hexColor(_selectedColor).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: kSpace8),
                Text(
                  _nameCtrl.text.isEmpty ? 'Project Name' : _nameCtrl.text,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: kSpace24),

          // Name field
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              hintText: 'e.g. Work, Personal, Shopping…',
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: kSpace24),

          // Emoji picker
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: kSpace8),
          Wrap(
            spacing: kSpace8,
            runSpacing: kSpace8,
            children: _kEmojis.map((e) => GestureDetector(
              onTap: () => setState(() => _selectedEmoji = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _selectedEmoji == e
                      ? _hexColor(_selectedColor).withOpacity(0.2)
                      : Colors.transparent,
                  border: Border.all(
                    color: _selectedEmoji == e ? _hexColor(_selectedColor) : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
              ),
            )).toList(),
          ),

          const SizedBox(height: kSpace24),

          // Color picker
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: kSpace8),
          Wrap(
            spacing: kSpace8,
            runSpacing: kSpace8,
            children: _kColors.map((c) => GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _hexColor(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == c ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: _selectedColor == c
                      ? [BoxShadow(color: _hexColor(c).withOpacity(0.5), blurRadius: 6)]
                      : null,
                ),
                child: _selectedColor == c
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return kP3Blue;
    }
  }
}
