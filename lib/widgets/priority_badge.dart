import 'package:flutter/material.dart';
import '../constants/theme.dart';

class PriorityBadge extends StatelessWidget {
  final int priority;
  final bool showLabel;
  final double size;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    final label = priorityLabel(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: size, color: color),
          if (showLabel) ...[
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: size - 2,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
