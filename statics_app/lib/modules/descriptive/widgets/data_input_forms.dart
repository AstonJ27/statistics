import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// Enum público
enum InputMode { generator, csv, frequencyTable, histogram }

// Callback actualizado
typedef OnDataReady = void Function(List<double> data, int k, double? min, double? max);

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
  
  // Controladores Globales (Configuración Rápida)
  final TextEditingController _totalNCtrl = TextEditingController();
  final TextEditingController _startValCtrl = TextEditingController(); // Nuevo: Límite Inicial
  final TextEditingController _amplitudeCtrl = TextEditingController(); // Nuevo: Amplitud Constante

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

  // Lógica CSV (Igual)
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
      // k=0 para Sturges, min/max null para auto-detectar
      widget.onDataReady(data, 0, null, null); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en CSV: $e"), backgroundColor: Colors.red));
    }
  }

  // --- LÓGICA PRINCIPAL HÍBRIDA ---
  void _processAggregatedData() {
    try {
      List<double> expandedData = [];
      double totalN = double.tryParse(_totalNCtrl.text) ?? 100.0;
      int validRows = 0;
      
      // Variables para los límites reales detectados o calculados
      double? detectedMin;
      double? detectedMax;

      // 1. Revisar si hay Configuración Rápida (Amplitud)
      double? globalStart = double.tryParse(_startValCtrl.text);
      double? globalAmp = double.tryParse(_amplitudeCtrl.text);
      bool useFastMode = (globalAmp != null && globalAmp > 0);

      // Si usamos modo rápido para Tabla, necesitamos el inicio obligatoriamente
      if (useFastMode && widget.mode == InputMode.frequencyTable && globalStart == null) {
        throw Exception("Para usar la Amplitud automática en Tabla, ingrese el Límite Inicial.");
      }

      for (int i = 0; i < _tableRows.length; i++) {
        var row = _tableRows[i];
        String freqTxt = row["freq"]!.text;
        if (freqTxt.isEmpty) continue; // Saltar filas vacías

        double freqVal = double.parse(freqTxt);
        double point; // Marca de clase (xi)
        
        // --- CÁLCULO DE INTERVALOS Y MARCA ---
        
        if (useFastMode) {
          // === MODO RÁPIDO (Automático) ===
          if (widget.mode == InputMode.frequencyTable) {
            // Tabla: Calculamos límites secuenciales
            // LimInf = Start + (i * W)
            double rowMin = globalStart! + (validRows * globalAmp);
            double rowMax = rowMin + globalAmp;
            point = (rowMin + rowMax) / 2; // Marca calculada matemáticamente

            // Capturar límites globales
            if (validRows == 0) detectedMin = rowMin;
            detectedMax = rowMax; // Se actualiza en cada iteración, quedando el último
            
          } else {
            // Histograma: Tenemos Marca, calculamos Límites con Amplitud
            String midTxt = row["midpoint"]!.text;
            if (midTxt.isEmpty) throw Exception("Fila ${i+1}: Ingrese la Marca para el Histograma.");
            point = double.parse(midTxt);
            
            // Inferencia exacta gracias a la amplitud dada
            double rowMin = point - (globalAmp / 2);
            double rowMax = point + (globalAmp / 2);
            
            // Capturar límites globales
            detectedMin ??= rowMin; // Solo el primero
            detectedMax = rowMax;   // Actualizar siempre
          }

        } else {
          // === MODO MANUAL (Límite por Límite) ===
          String lowerTxt = row["lower"]!.text;
          String upperTxt = row["upper"]!.text;
          String midTxt = row["midpoint"]!.text;

          // Intentar capturar límites manuales
          double? rowMin = lowerTxt.isNotEmpty ? double.tryParse(lowerTxt) : null;
          double? rowMax = upperTxt.isNotEmpty ? double.tryParse(upperTxt) : null;

          if (validRows == 0 && rowMin != null) detectedMin = rowMin;
          if (rowMax != null) detectedMax = rowMax;

          // Determinar Marca
          if (midTxt.isNotEmpty) {
            point = double.parse(midTxt);
          } else if (rowMin != null && rowMax != null) {
            point = (rowMin + rowMax) / 2;
          } else {
            throw Exception("Fila ${i+1}: Faltan datos (Límites o Marca).");
          }
        }

        // --- EXPANSIÓN DE DATOS ---
        int count = _isRelativeFreq ? (freqVal * totalN).round() : freqVal.round();
        for (int k = 0; k < count; k++) {
          expandedData.add(point);
        }
        
        validRows++;
      }

      if (expandedData.isEmpty) throw Exception("Datos insuficientes");
      
      // Enviamos a Rust los datos expandidos, k, y los límites exactos calculados/leídos
      widget.onDataReady(expandedData, validRows, detectedMin, detectedMax);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == InputMode.csv) return _buildCsvForm();
    // Reutilizamos el mismo form para Tabla e Histograma
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
        // 1. CONFIGURACIÓN GLOBAL (Tipo, N, Amplitud)
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
        
        // 2. CONFIGURACIÓN RÁPIDA (Amplitud e Inicio)
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
                  // Para histograma el inicio no es critico globalmente (se usa marca), para tabla sí.
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

        // 3. ENCABEZADOS DE COLUMNAS
        Row(
          children: [
            const SizedBox(width: 30, child: Text("#", style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
            const SizedBox(width: 5),
            
            // Si es Histograma, NO mostramos inputs de limites (se infieren o no se usan)
            // Si es Tabla, SÍ mostramos limites manuales
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

        // 4. FILAS DINÁMICAS
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

        // 5. BOTONES
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