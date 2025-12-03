// lib/widgets/freq_table_widget.dart

import 'package:flutter/material.dart';
import '../models.dart';

// Definimos el color aquí o impórtalo de main si prefieres, 
// pero para aislar el widget lo pondré aquí.
const Color tableBg = Color(0xFF323271); // BG_PRIMARY
final Color tableText = Colors.white;

class FrequencyTableWidget extends StatelessWidget {
  final FrequencyTable table;
  final Color backgroundColor;
  final Color textColor;
  const FrequencyTableWidget({
    super.key, 
    required this.table,
    this.backgroundColor = const Color(0xFF323271), // valor por defecto
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos Theme para forzar los estilos de la DataTable
    return Container(
      color: backgroundColor, // Fondo oscuro
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: tableText, // Color de las líneas
          iconTheme: IconThemeData(color: tableText), //tableText,
        ),
        // Permitir scroll vertical (para filas) y horizontal (para columnas)
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            child: DataTable(
              // Color de las líneas divisorias
              border: TableBorder(
                horizontalInside: BorderSide(color: textColor.withOpacity(0.5), width: 0.5),
                bottom: BorderSide(color: textColor, width: 1),
              ),
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.white, // Encabezados blancos para resaltar más
              ),
              dataTextStyle: TextStyle(
                color: textColor, // Datos en gris claro
              ),
              columns: const [
                DataColumn(label: Text('Clase')),
                DataColumn(label: Text('Intervalo')),
                DataColumn(label: Text('Marca')),
                DataColumn(label: Text('Fa')),
                DataColumn(label: Text('Fr')),
                DataColumn(label: Text('Fa Acum')),
                DataColumn(label: Text('Fr Acum')),
              ],
              rows: List<DataRow>.generate(table.classes.length, (i) {
                final c = table.classes[i];
                final intervalo = '[${c.lower.toStringAsFixed(2)} - ${c.upper.toStringAsFixed(2)})';
                return DataRow(cells: [
                  DataCell(Text('${i+1}')),
                  DataCell(Text(intervalo)),
                  DataCell(Text(c.midpoint.toStringAsFixed(3))),
                  DataCell(Text(c.absFreq.toString())),
                  DataCell(Text(c.relFreq.toStringAsFixed(4))),
                  DataCell(Text(c.cumAbs.toString())),
                  DataCell(Text(c.cumRel.toStringAsFixed(4))),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}