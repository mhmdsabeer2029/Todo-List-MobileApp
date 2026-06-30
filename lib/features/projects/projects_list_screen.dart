import 'package:flutter/material.dart';
import '../../store/project_store.dart';
import '../../store/task_store.dart';
import '../../models/index.dart';
import '../../constants/theme.dart';
import 'project_screen.dart';
import 'create_project_screen.dart';

class ProjectsListScreen extends StatelessWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final projectStore = ProjectStore();
    final taskStore = TaskStore();

    return AnimatedBuilder(
      animation: Listenable.merge([projectStore, taskStore]),
      builder: (context, _) {
        final projects = projectStore.activeProjects;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Projects', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
                ),
              ),
            ],
          ),
          body: projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined, size: 64, color: kTextMuted),
                      const SizedBox(height: kSpace16),
                      const Text('No projects yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: kSpace8),
                      const Text('Create a project to organize your tasks',
                          style: TextStyle(color: kTextMuted)),
                      const SizedBox(height: kSpace24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('New Project'),
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (ctx, i) {
                    final p = projects[i];
                    final taskCount = taskStore.tasksForProject(p.id)
                        .where((t) => !t.isCompleted)
                        .length;
                    return _ProjectTile(
                      project: p,
                      taskCount: taskCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectScreen(projectId: p.id),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  final int taskCount;
  final VoidCallback onTap;

  const _ProjectTile({
    required this.project,
    required this.taskCount,
    required this.onTap,
  });

  Color get _color {
    try {
      return Color(int.parse(project.color.replaceAll('#', '0xFF')));
    } catch (_) {
      return kP3Blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(project.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
      title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (project.isFavorite)
            const Icon(Icons.star, size: 14, color: kP2Orange),
          const SizedBox(width: 4),
          if (taskCount > 0)
            Text('$taskCount',
                style: const TextStyle(color: kTextMuted, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: kTextMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}
