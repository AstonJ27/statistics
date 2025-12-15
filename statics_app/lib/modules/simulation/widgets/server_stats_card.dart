import 'package:flutter/material.dart';
import '../models/simulation_models.dart';
import '../../../core/theme/app_colors.dart';

class ServerStatsCard extends StatelessWidget {
  final SimulationResult result;
  const ServerStatsCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Detalle por Hora y Vehículo", 
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.hours.length,
              itemBuilder: (context, index) {
                final h = result.hours[index];
                return Card(
                  color: Colors.black12,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white54,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 16,
                      child: Text("${h.hourIndex}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    title: Text("Llegadas: ${h.estimated} | Atendidos: ${h.served}", 
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(0),
                          itemCount: h.cars.length,
                          separatorBuilder: (_,__) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (ctx, carIdx) {
                            return _buildCarItem(h.cars[carIdx]);
                          },
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarItem(CarResult car) {
    IconData icon = Icons.check_circle_outline;
    Color color = AppColors.green;
    if (car.left) { icon = Icons.cancel_outlined; color = Colors.redAccent; }
    else if (car.pending) { icon = Icons.hourglass_empty; color = Colors.orangeAccent; }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Vehículo #${car.id}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Llegada: ${car.arrivalMinute.toStringAsFixed(2)} min", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statRow("Espera:", "${car.waitTime.toStringAsFixed(2)}m", Colors.orangeAccent),
              // Nuevo campo de Ocio
              _statRow("Ocio Gen.:", "${car.idleTime.toStringAsFixed(2)}m", Colors.blueAccent),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _statRow(String label, String val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(width: 4),
        Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}