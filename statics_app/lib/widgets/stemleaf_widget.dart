// lib/widgets/stemleaf_widget.dart
import 'package:flutter/material.dart';
import '../models.dart';

class StemLeafWidget extends StatelessWidget {
  final List<StemLeafItem> items;
  const StemLeafWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // build lines like "stem | leaves"
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((it) {
            final leaves = it.leaves.map((e) => e.toString()).join(' ');
            return Text('${it.stem.toString().padLeft(3)} | $leaves', style: TextStyle(fontFamily: 'monospace'));
          }).toList(),
        ),
      ),
    );
  }
}
