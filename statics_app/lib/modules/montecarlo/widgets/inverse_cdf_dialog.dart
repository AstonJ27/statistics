import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';

class InverseCdfDialog extends StatefulWidget {
  const InverseCdfDialog({super.key});

  @override
  State<InverseCdfDialog> createState() => _InverseCdfDialogState();
}

class _InverseCdfDialogState extends State<InverseCdfDialog> {
  String _distType = 'normal';
  final _probCtrl = TextEditingController(text: "0.95");
  
  // Parámetros dinámicos
  final _p1Ctrl = TextEditingController(text: "0"); 
  final _p2Ctrl = TextEditingController(text: "1"); 

  String _resultText = "";
  String _zScoreText = "";
  bool _loading = false;

  Future<void> _calculate() async {
    setState(() { _loading = true; _resultText = ""; _zScoreText = ""; });
    
    try {
      double p = double.tryParse(_probCtrl.text) ?? -1;
      if(p <= 0 || p >= 1) throw Exception("La probabilidad debe estar entre 0 y 1 (exclusivo).");

      Map<String, dynamic> req = {
        "dist_type": _distType,
        "probability": p,
        "param1": double.parse(_p1Ctrl.text),
        "param2": double.parse(_p2Ctrl.text),
      };

      // Nota: Asegúrate de haber agregado calculateInverseCdf a NativeService (Paso 3 y 4)
      final jsonStr = await NativeService.calculateInverseCdf(req);
      final res = jsonDecode(jsonStr);

      if (res.containsKey('error')) throw Exception(res['error']);

      setState(() {
        double val = (res['value'] as num).toDouble();
        _resultText = val.toStringAsFixed(4);
        
        if (res['z_score'] != null) {
          _zScoreText = "Valor Z = ${(res['z_score'] as num).toStringAsFixed(4)}";
        }
      });

    } catch (e) {
      setState(() { _resultText = "Error"; _zScoreText = e.toString().replaceAll("Exception:", ""); });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.functions, color: AppColors.green),
          SizedBox(width: 8),
          Text("Calculadora Inversa", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Convierte una probabilidad (U) en el valor (X) de la distribución.", 
              style: TextStyle(color: Colors.white54, fontSize: 12)
            ),
            const SizedBox(height: 20),
            
            // Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _distType,
                  dropdownColor: AppColors.bgCard,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text("Normal")),
                    DropdownMenuItem(value: 'exponential', child: Text("Exponencial")),
                    DropdownMenuItem(value: 'uniform', child: Text("Uniforme")),
                  ],
                  onChanged: (v) => setState(() { 
                    _distType = v!;
                    if(_distType == 'normal') { _p1Ctrl.text = "0"; _p2Ctrl.text = "1"; }
                    if(_distType == 'exponential') { _p1Ctrl.text = "10"; _p2Ctrl.text = "0"; }
                    if(_distType == 'uniform') { _p1Ctrl.text = "0"; _p2Ctrl.text = "10"; }
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Inputs Parámetros
            Row(
              children: [
                Expanded(child: _buildParamInput(1)),
                if (_distType != 'exponential') ...[
                  const SizedBox(width: 12),
                  Expanded(child: _buildParamInput(2)),
                ]
              ],
            ),
            const SizedBox(height: 16),

            // Input Probabilidad
            TextField(
              controller: _probCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: _inputDec("Aleatorio U (0-1)", icon: Icons.casino),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 24),
            
            // Resultado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.5))
              ),
              child: Column(
                children: [
                  const Text("Valor Simulado (X)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(_resultText.isEmpty ? "---" : _resultText, 
                    style: const TextStyle(color: AppColors.green, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  if (_zScoreText.isNotEmpty) 
                    Text(_zScoreText, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                ],
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Cerrar", style: TextStyle(color: Colors.white38))
        ),
        ElevatedButton(
          onPressed: _calculate, 
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
          child: _loading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgPrimary)) 
            : const Text("CALCULAR", style: TextStyle(color: AppColors.bgPrimary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildParamInput(int idx) {
    String label = "";
    if (_distType == 'normal') label = idx == 1 ? "Media (μ)" : "Varianza (σ²)";
    if (_distType == 'exponential') label = idx == 1 ? "Beta" : "-";
    if (_distType == 'uniform') label = idx == 1 ? "Mín" : "Máx";

    return TextField(
      controller: idx == 1 ? _p1Ctrl : _p2Ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDec(label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  InputDecoration _inputDec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      isDense: true, filled: true, fillColor: Colors.black26,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.white38) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.green)),
    );
  }
}