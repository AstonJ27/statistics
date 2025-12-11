import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/descriptive_models.dart';

class SummaryStatsCard extends StatelessWidget {
  final AnalyzeResult result;

  const SummaryStatsCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    String modeText = "N/A";
    if (result.mode.isEmpty) {
      modeText = "Sin moda";
    } else if (result.mode.length > 3) {
      modeText = "Multimodal (${result.mode.length})";
    } else {
      modeText = result.mode.map((e) => e.toStringAsFixed(2)).join(', ');
    }

    final List<Map<String, Object>> stats = [
      {'label': 'Muestras (n)', 'value': '${result.n}'},
      {'label': 'Media', 'value': result.mean.toStringAsFixed(4)},
      {'label': 'CV (%)', 'value': '${result.cv.toStringAsFixed(2)}%'},
      {'label': 'Mediana', 'value': result.median.toStringAsFixed(4)},
      {'label': 'Moda', 'value': modeText},
      {'label': 'Desv. Est. (S)', 'value': result.std.toStringAsFixed(4)},
      {'label': 'Varianza (S²)', 'value': result.variance.toStringAsFixed(4)},
      {'label': 'Mínimo', 'value': result.min.toStringAsFixed(4)},
      {'label': 'Máximo', 'value': result.max.toStringAsFixed(4)},
      {'label': 'Rango', 'value': result.range.toStringAsFixed(4)},
      {'label': 'Asimetría', 'value': result.skewness.toStringAsFixed(4)},
      {'label': 'Curtosis', 'value': result.kurtosis.toStringAsFixed(4)},
      {'label': 'Clases (k)', 'value': '${result.k}'},
      {'label': 'Amplitud (A)', 'value': result.amplitude.toStringAsFixed(4)},
    ];

    if (result.bestFit != null) {
      stats.add({
        'label': 'Mejor Ajuste', 
        'value': '${result.bestFit!['name']}', 
        'highlight': true
      });
      stats.add({
        'label': 'AIC', 
        'value': '${(result.bestFit!['aic'] as num).toStringAsFixed(2)}'
      });
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resumen Estadístico", 
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.map((item) => _statItem(
                item['label'] as String, 
                item['value'] as String,
                isHighlight: item['highlight'] == true
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {bool isHighlight = false}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600), 
            textAlign: TextAlign.center, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              color: isHighlight ? AppColors.primary : Colors.black87, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ), 
            textAlign: TextAlign.center
          ),
        ],
      ),
    );
  }
}