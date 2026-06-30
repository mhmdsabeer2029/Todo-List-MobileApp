import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../store/task_store.dart';
import '../../store/project_store.dart';
import '../../store/label_store.dart';
import '../../utils/google_auth_service.dart';
import '../../utils/sheets_import_service.dart';

/// Lets the signed-in Google user pick a spreadsheet from their Drive,
/// scans it precisely via the Sheets API, runs the grid through Groq to
/// identify actionable tasks, and lets them review/select before bulk
/// importing into their task list.
class SheetsImportScreen extends StatefulWidget {
  const SheetsImportScreen({super.key});

  @override
  State<SheetsImportScreen> createState() => _SheetsImportScreenState();
}

enum _Stage { pickFile, scanning, review, importing, done }

class _SheetsImportScreenState extends State<SheetsImportScreen> {
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final SheetsImportService _importService = SheetsImportService();
  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final LabelStore _labelStore = LabelStore();

  _Stage _stage = _Stage.pickFile;
  List<DriveFile> _files = [];
  String? _error;
  DriveFile? _selectedFile;
  List<SheetTaskCandidate> _candidates = [];
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _error = null;
      _stage = _Stage.pickFile;
    });
    try {
      final files = await _googleAuth.listSpreadsheets();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Could not load your Google Sheets. Make sure Google Sign-In '
            'is configured (see GoogleAuthService.setupInstructions) and '
            'that you are signed in.\n\n$e');
      }
    }
  }

  Future<void> _scanFile(DriveFile file) async {
    setState(() {
      _selectedFile = file;
      _stage = _Stage.scanning;
      _error = null;
    });
    try {
      final grid = await _googleAuth.fetchSpreadsheetData(file.id);
      final candidates = await _importService.extractTasks(grid);
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _stage = _Stage.review;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to scan "${file.name}": $e';
          _stage = _Stage.pickFile;
        });
      }
    }
  }

  Future<void> _importSelected() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _stage = _Stage.importing);

    var count = 0;
    for (final c in selected) {
      String? projectId;
      if (c.project != null && c.project!.trim().isNotEmpty) {
        final existing = _projectStore.projects
            .where((p) => p.name.toLowerCase() == c.project!.toLowerCase())
            .toList();
        if (existing.isNotEmpty) {
          projectId = existing.first.id;
        } else {
          final created = await _projectStore.addProject(name: c.project!);
          projectId = created.id;
        }
      }

      int priority = 4;
      switch (c.priority) {
        case 'p1':
          priority = 1;
          break;
        case 'p2':
          priority = 2;
          break;
        case 'p3':
          priority = 3;
          break;
      }

      // Resolve (or create) each label the same way projects are resolved
      // above, instead of silently dropping them — the review screen shows
      // labels as part of what will be imported, so they need to actually
      // be imported.
      final labelIds = <String>[];
      for (final labelName in c.labels) {
        final trimmed = labelName.trim();
        if (trimmed.isEmpty) continue;
        final existingLabel = _labelStore.labels
            .where((l) => l.name.toLowerCase() == trimmed.toLowerCase())
            .toList();
        if (existingLabel.isNotEmpty) {
          labelIds.add(existingLabel.first.id);
        } else {
          final createdLabel = await _labelStore.addLabel(name: trimmed);
          labelIds.add(createdLabel.id);
        }
      }

      await _taskStore.addTask(
        title: c.title,
        description: c.notes ?? '',
        projectId: projectId,
        priority: priority,
        dueDate: c.dueDate,
        labelIds: labelIds,
      );
      count++;
    }

    if (mounted) {
      setState(() {
        _importedCount = count;
        _stage = _Stage.done;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Google Sheets')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.pickFile:
        return _buildFilePicker();
      case _Stage.scanning:
        return _buildLoading('Scanning "${_selectedFile?.name}" with Groq...\nReading every row precisely.');
      case _Stage.review:
        return _buildReview();
      case _Stage.importing:
        return _buildLoading('Importing tasks...');
      case _Stage.done:
        return _buildDone();
    }
  }

  Widget _buildFilePicker() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(kSpace24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: kP1Red),
            const SizedBox(height: kSpace16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: kSpace16),
            FilledButton(onPressed: _loadFiles, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: kSpace8),
      itemCount: _files.length,
      itemBuilder: (ctx, i) {
        final f = _files[i];
        return ListTile(
          leading: const Icon(Icons.grid_on, color: kSuccess),
          title: Text(f.name),
          subtitle: f.modifiedTime != null ? Text('Modified ${f.modifiedTime}') : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _scanFile(f),
        );
      },
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: kSpace16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    if (_candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(kSpace24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off, size: 48, color: kTextMuted),
            SizedBox(height: kSpace16),
            Text('No actionable tasks found in this sheet.', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final selectedCount = _candidates.where((c) => c.selected).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(kSpace16),
          child: Row(
            children: [
              Expanded(
                child: Text('$selectedCount of ${_candidates.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final allSelected = _candidates.every((c) => c.selected);
                  for (final c in _candidates) {
                    c.selected = !allSelected;
                  }
                }),
                child: const Text('Toggle all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _candidates.length,
            itemBuilder: (ctx, i) {
              final c = _candidates[i];
              return CheckboxListTile(
                value: c.selected,
                onChanged: (v) => setState(() => c.selected = v ?? false),
                title: Text(c.title),
                subtitle: Text([
                  if (c.dueDate != null) 'Due ${c.dueDate}',
                  if (c.priority != null) c.priority!.toUpperCase(),
                  if (c.project != null) c.project!,
                  if (c.labels.isNotEmpty) c.labels.join(', '),
                ].where((s) => s.isNotEmpty).join(' • ')),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(kSpace16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selectedCount > 0 ? _importSelected : null,
              child: Text('Import $selectedCount task${selectedCount == 1 ? '' : 's'}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 56, color: kSuccess),
            const SizedBox(height: kSpace16),
            Text('Imported $_importedCount task${_importedCount == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: kSpace16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
