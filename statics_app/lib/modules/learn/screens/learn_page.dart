import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// Importamos los paquetes de soporte LaTeX
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/theme/app_colors.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Detectamos si la pantalla es estrecha (móvil)
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text("Teoría: FGM", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder(
        future: rootBundle.loadString("assets/docs/mgf_content.md"),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          return Markdown(
            data: snapshot.data ?? "",
            padding: const EdgeInsets.all(16),
            selectable: true,
            
            // --- CONFIGURACIÓN RESPONSIVE DE LATEX ---
            builders: {
              'latex': LatexElementBuilder(
                textStyle: const TextStyle(color: Colors.white),
                // Reducimos un poco la escala en móviles para que quepan más símbolos
                textScaleFactor: isMobile ? 1.1 : 1.4, 
              ),
            },
            extensionSet: md.ExtensionSet(
              [
                ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                LatexBlockSyntax(), // Permite bloques $$ ... $$
              ],
              [
                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                LatexInlineSyntax(), // Permite inline $ ... $
              ],
            ),
            // ----------------------------------------

            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
              h1: const TextStyle(color: AppColors.green, fontSize: 24, fontWeight: FontWeight.bold),
              h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 3), // Más espacio antes del título
              strong: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
              // Fondo para los bloques de código o citas
              blockquote: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic),
              blockquoteDecoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppColors.green, width: 4))
              ),
            ),
          );
        },
      ),
    );
  }
}