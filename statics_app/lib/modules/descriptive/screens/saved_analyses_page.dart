// lib/modules/descriptive/screens/saved_analyses_page.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/analysis_storage_service.dart';

class SavedAnalysesPage extends StatefulWidget {
  final Function(SavedAnalysis) onLoad; // Callback cuando el usuario elige uno

  const SavedAnalysesPage({super.key, required this.onLoad});

  @override
  State<SavedAnalysesPage> createState() => _SavedAnalysesPageState();
}

class _SavedAnalysesPageState extends State<SavedAnalysesPage> {
  final AnalysisStorageService _storage = AnalysisStorageService();
  List<SavedAnalysis> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _storage.getAll();
    setState(() {
      _list = data;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    await _storage.deleteAnalysis(id);
    _loadData(); // Recargar lista
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text("Análisis Guardados", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text("No hay análisis guardados", style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final item = _list[index];
                    return Card(
                      color: AppColors.bgCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text("${_list.length - index}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "Modo: ${item.mode.name.toUpperCase()}",
                              style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Fecha: ${item.date.toLocal().toString().split('.')[0]}",
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _showDeleteConfirm(item.id),
                        ),
                        onTap: () {
                          widget.onLoad(item);
                          Navigator.pop(context); // Volver a la pantalla principal
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text("Eliminar", style: TextStyle(color: Colors.white)),
        content: const Text("¿Estás seguro de eliminar este análisis?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: const Text("Cancelar"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)), 
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id);
            }
          ),
        ],
      )
    );
  }
}