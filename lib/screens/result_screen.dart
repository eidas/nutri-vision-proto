import 'package:flutter/material.dart';
import '../models/nutrition_data.dart';
import '../services/export_service.dart';
import '../widgets/nutrition_table_widget.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.data});
  final NutritionData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('読み取り結果'),
        actions: [_ExportButton(data: data)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfidenceBadge(confidence: data.confidence),
            const SizedBox(height: 16),
            NutritionTableWidget(data: data),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Export button ─────────────────────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.data});
  final NutritionData data;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ExportAction>(
      icon: const Icon(Icons.ios_share),
      onSelected: (action) => _handle(context, action),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportAction.copyJson,
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('JSON をコピー'),
          ),
        ),
        PopupMenuItem(
          value: _ExportAction.shareJson,
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('JSON として共有'),
          ),
        ),
        PopupMenuItem(
          value: _ExportAction.shareCsv,
          child: ListTile(
            leading: Icon(Icons.table_chart),
            title: Text('CSV として共有'),
          ),
        ),
      ],
    );
  }

  Future<void> _handle(BuildContext context, _ExportAction action) async {
    final svc = ExportService.instance;
    switch (action) {
      case _ExportAction.copyJson:
        await svc.copyJsonToClipboard(data);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON をクリップボードにコピーしました')),
        );
      case _ExportAction.shareJson:
        await svc.shareAsJson(data);
      case _ExportAction.shareCsv:
        await svc.shareAsCsv(data);
    }
  }
}

enum _ExportAction { copyJson, shareJson, shareCsv }

// ── Confidence badge ──────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toInt();
    final color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.5
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Icon(Icons.verified_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '読取精度 $pct%',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
