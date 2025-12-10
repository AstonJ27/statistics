import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Enum público para controlar qué formulario mostrar
enum InputMode { generator, csv, frequencyTable, histogram }

// Callback para devolver los datos procesados al padre
typedef OnDataReady = void Function(List<double> data, int k);

class DataInputForms extends StatefulWidget {
  final InputMode mode;
  final OnDataReady onDataReady;

  const DataInputForms({super.key, required this.mode, required this.onDataReady});

  @override
  State<DataInputForms> createState() => _DataInputFormsState();
}

class _DataInputFormsState extends State<DataInputForms> {
  // --- CONTROLADORES CSV ---
  final TextEditingController _csvCtrl = TextEditingController();

  // --- CONTROLADORES TABLA/HISTOGRAMA ---
  List<Map<String, TextEditingController>> _tableRows = [];
  bool _isRelativeFreq = false;
  final TextEditingController _totalNCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addTableRow();
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
      // k=0 para que Rust use Sturges
      widget.onDataReady(data, 0); 
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en CSV: $e"), backgroundColor: Colors.red));
    }
  }

  void _processAggregatedData() {
    try {
      List<double> expandedData = [];
      double totalN = double.tryParse(_totalNCtrl.text) ?? 100.0;
      int validRows = 0;
      
      for (var row in _tableRows) {
        String lowerTxt = row["lower"]!.text;
        String upperTxt = row["upper"]!.text;
        String midTxt = row["midpoint"]!.text;
        String freqTxt = row["freq"]!.text;

        if (freqTxt.isEmpty) continue;

        double freqVal = double.parse(freqTxt);
        double point;

        if (midTxt.isNotEmpty) {
          point = double.parse(midTxt);
        } else if (lowerTxt.isNotEmpty && upperTxt.isNotEmpty) {
          point = (double.parse(lowerTxt) + double.parse(upperTxt)) / 2;
        } else {
          throw Exception("Fila incompleta: Ingrese Marca o Límites");
        }

        int count;
        if (_isRelativeFreq) {
          count = (freqVal * totalN).round(); 
        } else {
          count = freqVal.round();
        }

        for (int i = 0; i < count; i++) {
          expandedData.add(point);
        }
        validRows++;
      }

      if (expandedData.isEmpty) throw Exception("Datos insuficientes para generar muestra");
      
      widget.onDataReady(expandedData, validRows);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error procesando tabla: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == InputMode.csv) return _buildCsvForm();
    if (widget.mode == InputMode.frequencyTable) return _buildTableForm(showLimits: true);
    if (widget.mode == InputMode.histogram) return _buildTableForm(showLimits: false);
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
            hintText: "Pega tus datos separados por coma, espacio o enter (ej: 12.5, 10.2, 5.5...)",
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

  Widget _buildTableForm({required bool showLimits}) {
    return Column(
      children: [
        // Configuración Global de la Tabla
        Row(
          children: [
            const Text("Tipo Frecuencia:", style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<bool>(
                value: _isRelativeFreq,
                dropdownColor: AppColors.bgCard,
                isDense: true,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: false, child: Text("Absoluta (Conteo)")),
                  DropdownMenuItem(value: true, child: Text("Relativa (0.0 - 1.0)")),
                ],
                onChanged: (v) => setState(() => _isRelativeFreq = v!),
              ),
            ),
          ],
        ),
        if (_isRelativeFreq)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, top: 5.0),
            child: TextField(
              controller: _totalNCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: "Total de Datos (N estimado)",
                hintText: "Ej: 100",
                isDense: true,
                filled: true, fillColor: Colors.black12,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        
        const SizedBox(height: 10),

        // ENCABEZADOS (HEADERS) - Restaurados y Alineados
        Row(
          children: [
            // Espacio para índice (#)
            const SizedBox(width: 30, child: Text("#", style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
            const SizedBox(width: 5),
            
            if (showLimits) ...[
              const Expanded(child: Text("Lim. Inf", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 5),
              const Expanded(child: Text("Lim. Sup", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 5),
            ],
            const Expanded(child: Text("Marca (xi)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 5),
            Expanded(child: Text(_isRelativeFreq ? "Fr. Rel (hi)" : "Frec (fi)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 40), // Espacio equivalente al botón de borrar
          ],
        ),
        
        const Divider(color: Colors.white24, height: 10),

        // FILAS DE DATOS
        ..._tableRows.asMap().entries.map((entry) {
          int idx = entry.key;
          var row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Row(
              children: [
                // Índice de Fila
                SizedBox(
                  width: 30,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white10,
                    child: Text("${idx + 1}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 5),

                if (showLimits) ...[
                  Expanded(child: _miniInput(row["lower"]!)),
                  const SizedBox(width: 5),
                  Expanded(child: _miniInput(row["upper"]!)),
                  const SizedBox(width: 5),
                ],
                Expanded(child: _miniInput(row["midpoint"]!)), // Marca necesaria para histograma
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

        // BOTONES DE ACCIÓN
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

  Widget _miniInput(TextEditingController ctrl) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          filled: true, fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}