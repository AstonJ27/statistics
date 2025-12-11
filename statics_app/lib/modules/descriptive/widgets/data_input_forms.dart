// lib/modules/descriptive/widgets/data_input_forms.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Enum público
enum InputMode { generator, csv, frequencyTable, histogram }

// Callback actualizado
typedef OnDataReady = void Function(List<double> data, int k, double? min, double? max);

class DataInputForms extends StatefulWidget {
  final InputMode mode;
  final OnDataReady onDataReady;
  
  // --- NUEVO: Datos iniciales para restaurar ---
  final Map<String, dynamic>? initialData;

  const DataInputForms({
    super.key, 
    required this.mode, 
    required this.onDataReady,
    this.initialData,
  });

  @override
  State<DataInputForms> createState() => DataInputFormsState(); // Hacemos pública la clase State removiendo el guion bajo si fuera necesario, pero con GlobalKey funciona así.
}

class DataInputFormsState extends State<DataInputForms> { // Renombrado a público para usar GlobalKey
  // --- CONTROLADORES CSV ---
  final TextEditingController _csvCtrl = TextEditingController();

  // --- CONTROLADORES TABLA/HISTOGRAMA ---
  List<Map<String, TextEditingController>> _tableRows = [];
  bool _isRelativeFreq = false;
  
  // Controladores Globales
  final TextEditingController _totalNCtrl = TextEditingController();
  final TextEditingController _startValCtrl = TextEditingController();
  final TextEditingController _amplitudeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // LÓGICA DE RESTAURACIÓN
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _restoreFromData();
    } else {
      _addTableRow();
    }
  }

  // Detecta si cambiamos de modo pero teníamos datos iniciales viejos, limpia si es necesario
  @override
  void didUpdateWidget(covariant DataInputForms oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
       if (widget.initialData != null) {
         _restoreFromData();
       }
    }
  }

  void _restoreFromData() {
    final d = widget.initialData!;
    
    // Restaurar CSV
    if (widget.mode == InputMode.csv && d.containsKey('csv_text')) {
       _csvCtrl.text = d['csv_text'] ?? '';
    }
    
    // Restaurar Tabla / Histograma
    if ((widget.mode == InputMode.frequencyTable || widget.mode == InputMode.histogram) && d.containsKey('rows')) {
        setState(() {
          _tableRows.clear();
          _isRelativeFreq = d['is_rel'] ?? false;
          _totalNCtrl.text = d['total_n']?.toString() ?? '';
          
          final rows = d['rows'] as List;
          for (var r in rows) {
             _tableRows.add({
                "lower": TextEditingController(text: r['lower']?.toString() ?? ''),
                "upper": TextEditingController(text: r['upper']?.toString() ?? ''),
                "midpoint": TextEditingController(text: r['midpoint']?.toString() ?? ''),
                "freq": TextEditingController(text: r['freq']?.toString() ?? ''),
             });
          }
        });
    }

    if (_tableRows.isEmpty && widget.mode != InputMode.csv) {
        _addTableRow();
    }
  }

  /// --- NUEVO MÉTODO PÚBLICO: Obtener estado actual para guardar ---
  Map<String, dynamic> getCurrentInputState() {
     if (widget.mode == InputMode.csv) {
         return {'csv_text': _csvCtrl.text};
     }
     
     // Mapear filas a JSON simple
     List<Map<String, dynamic>> rowsJson = _tableRows.map((row) => {
        'lower': row['lower']?.text,
        'upper': row['upper']?.text,
        'midpoint': row['midpoint']?.text,
        'freq': row['freq']?.text,
     }).toList();

     return {
         'rows': rowsJson,
         'total_n': _totalNCtrl.text,
         'is_rel': _isRelativeFreq
     };
  }

  void _addTableRow() {
    setState(() {
      _tableRows.add({
        "lower": TextEditingController(),
        "upper": TextEditingController(),
        "midpoint": TextEditingController(),
        "freq": TextEditingController(),
      });
    });
  }

  void _removeTableRow(int index) {
    if (_tableRows.length > 1) {
      setState(() => _tableRows.removeAt(index));
    }
  }

  // Lógica CSV
  void _processCsv() {
    try {
      final text = _csvCtrl.text.replaceAll(RegExp(r'[\n\r]'), ','); 
      final parts = text.split(RegExp(r'[,\s]+'));
      List<double> data = [];
      for (var p in parts) {
        if (p.trim().isNotEmpty) {
          final val = double.tryParse(p.trim());
          if (val != null) data.add(val);
        }
      }
      if (data.isEmpty) throw Exception("No se encontraron datos válidos");
      widget.onDataReady(data, 0, null, null); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en CSV: $e"), backgroundColor: Colors.red));
    }
  }

  // Lógica Tabla
  void _processAggregatedData() {
    try {
      List<double> expandedData = [];
      double totalN = double.tryParse(_totalNCtrl.text) ?? 100.0;
      int validRows = 0;
      
      double? detectedMin;
      double? detectedMax;

      double? globalStart = double.tryParse(_startValCtrl.text);
      double? globalAmp = double.tryParse(_amplitudeCtrl.text);
      bool useFastMode = (globalAmp != null && globalAmp > 0);

      if (useFastMode && widget.mode == InputMode.frequencyTable && globalStart == null) {
        throw Exception("Para usar la Amplitud automática en Tabla, ingrese el Límite Inicial.");
      }

      for (int i = 0; i < _tableRows.length; i++) {
        var row = _tableRows[i];
        String freqTxt = row["freq"]!.text;
        if (freqTxt.isEmpty) continue; 

        double freqVal = double.parse(freqTxt);
        double point; 
        
        if (useFastMode) {
          if (widget.mode == InputMode.frequencyTable) {
            double rowMin = globalStart! + (validRows * globalAmp);
            double rowMax = rowMin + globalAmp;
            point = (rowMin + rowMax) / 2;

            if (validRows == 0) detectedMin = rowMin;
            detectedMax = rowMax;
            
          } else {
            String midTxt = row["midpoint"]!.text;
            if (midTxt.isEmpty) throw Exception("Fila ${i+1}: Ingrese la Marca para el Histograma.");
            point = double.parse(midTxt);
            
            double rowMin = point - (globalAmp / 2);
            double rowMax = point + (globalAmp / 2);
            detectedMin ??= rowMin;
            detectedMax = rowMax;
          }

        } else {
          String lowerTxt = row["lower"]!.text;
          String upperTxt = row["upper"]!.text;
          String midTxt = row["midpoint"]!.text;

          double? rowMin = lowerTxt.isNotEmpty ? double.tryParse(lowerTxt) : null;
          double? rowMax = upperTxt.isNotEmpty ? double.tryParse(upperTxt) : null;

          if (validRows == 0 && rowMin != null) detectedMin = rowMin;
          if (rowMax != null) detectedMax = rowMax;

          if (midTxt.isNotEmpty) {
            point = double.parse(midTxt);
          } else if (rowMin != null && rowMax != null) {
            point = (rowMin + rowMax) / 2;
          } else {
            throw Exception("Fila ${i+1}: Faltan datos (Límites o Marca).");
          }
        }

        int count = _isRelativeFreq ? (freqVal * totalN).round() : freqVal.round();
        for (int k = 0; k < count; k++) {
          expandedData.add(point);
        }
        
        validRows++;
      }

      if (expandedData.isEmpty) throw Exception("Datos insuficientes");
      widget.onDataReady(expandedData, validRows, detectedMin, detectedMax);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == InputMode.csv) return _buildCsvForm();
    if (widget.mode == InputMode.frequencyTable) return _buildTableForm(isHistogram: false);
    if (widget.mode == InputMode.histogram) return _buildTableForm(isHistogram: true);
    return const SizedBox.shrink();
  }

  Widget _buildCsvForm() {
    return Column(
      children: [
        TextField(
          controller: _csvCtrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Pega tus datos separados por coma, espacio o enter...",
            filled: true, fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _processCsv,
          icon: const Icon(Icons.check),
          label: const Text("Procesar Datos CSV"),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        )
      ],
    );
  }

  Widget _buildTableForm({required bool isHistogram}) {
    return Column(
      children: [
        Row(
          children: [
            const Text("Tipo:", style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButton<bool>(
                value: _isRelativeFreq,
                dropdownColor: AppColors.bgCard,
                isDense: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                underline: Container(height: 1, color: Colors.white24),
                items: const [
                  DropdownMenuItem(value: false, child: Text("Absoluta")),
                  DropdownMenuItem(value: true, child: Text("Relativa")),
                ],
                onChanged: (v) => setState(() => _isRelativeFreq = v!),
              ),
            ),
            const SizedBox(width: 10),
            if (_isRelativeFreq)
              Expanded(flex: 2, child: _miniInput(_totalNCtrl, hint: "Total N", isHeader: true)),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Autocompletar (Opcional)", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Row(
                children: [
                  if (!isHistogram)
                    Expanded(child: _miniInput(_startValCtrl, hint: "Lim. Inicial (1ro)", isHeader: true)),
                  if (!isHistogram) const SizedBox(width: 8),
                  
                  Expanded(child: _miniInput(_amplitudeCtrl, hint: "Amplitud (W)", isHeader: true)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const SizedBox(width: 30, child: Text("#", style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
            const SizedBox(width: 5),
            
            if (!isHistogram) ...[
              const Expanded(child: Text("Inf", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 5),
              const Expanded(child: Text("Sup", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 5),
            ],
            
            const Expanded(child: Text("Marca (xi)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 5),
            Expanded(child: Text(_isRelativeFreq ? "hi" : "fi", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 40),
          ],
        ),
        
        const Divider(color: Colors.white24, height: 10),

        ..._tableRows.asMap().entries.map((entry) {
          int idx = entry.key;
          var row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white10,
                    child: Text("${idx + 1}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 5),

                if (!isHistogram) ...[
                  Expanded(child: _miniInput(row["lower"]!)),
                  const SizedBox(width: 5),
                  Expanded(child: _miniInput(row["upper"]!)),
                  const SizedBox(width: 5),
                ],
                Expanded(child: _miniInput(row["midpoint"]!)), 
                const SizedBox(width: 5),
                Expanded(child: _miniInput(row["freq"]!)),
                
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  onPressed: () => _removeTableRow(idx),
                )
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _addTableRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Agregar Fila"),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            ElevatedButton.icon(
              onPressed: _processAggregatedData,
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text("Calcular"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green, 
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _miniInput(TextEditingController ctrl, {String? hint, bool isHeader = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          filled: true, 
          fillColor: isHeader ? Colors.white.withOpacity(0.1) : Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}