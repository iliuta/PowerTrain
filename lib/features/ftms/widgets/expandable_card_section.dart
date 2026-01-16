import 'package:flutter/material.dart';

/// Reusable widget for an expandable card section with a header and collapsible content
class ExpandableCardSection extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onExpandChanged;
  final Widget content;
  final Widget? footer;

  const ExpandableCardSection({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.onExpandChanged,
    required this.content,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: onExpandChanged,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: content,
            ),
          if (isExpanded && footer != null) footer!,
        ],
      ),
    );
  }
}
