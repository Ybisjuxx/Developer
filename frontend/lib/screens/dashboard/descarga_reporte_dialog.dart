import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_service.dart';
import '../../utils/file_download_helper.dart';

void mostrarDialogoDescargaCsv(
  BuildContext context,
  String nombreArchivo,
  String periodo,
  String rol,
  String csvContent,
) {
  final ts = ThemeService.instance;
  final int lineas = '\n'.allMatches(csvContent).length + 1;
  final int bytes = utf8.encode(csvContent).length;

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: ts.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ts.accentPrimary.withValues(alpha: 0.35), width: 1.2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 580),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ts.tintBg(ts.neonGreen, lightAlpha: 0.15, darkAlpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.file_download_done_rounded, color: ts.neonGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reporte Mensual CSV Generado',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ts.textPrimary,
                              ),
                            ),
                            Text(
                              'Periodo: $periodo  •  Rol: $rol',
                              style: TextStyle(fontSize: 12, color: ts.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ts.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ts.surfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ts.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreArchivo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ts.accentPrimary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ruta servidor: reportes_mensuales/$periodo/  •  $lineas filas  •  ${(bytes / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(color: ts.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ts.neonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 14, color: ts.neonGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Copiado',
                              style: TextStyle(
                                color: ts.neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Previsualización de datos (formato tabular CSV):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ts.textSecondary),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ts.esOscuro ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SelectableText(
                          csvContent,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: ts.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ts.accentPrimary,
                        side: BorderSide(color: ts.accentPrimary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: csvContent));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: ts.neonGreen,
                              content: const Text(
                                '¡CSV copiado nuevamente al portapapeles!',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar Todo el CSV'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.neonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final ruta = await descargarArchivoTexto(
                          nombreArchivo,
                          csvContent,
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: ts.neonGreen,
                              content: Text(
                                ruta != null
                                    ? 'Archivo descargado: $ruta'
                                    : 'Descarga no soportada en esta plataforma.',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Descargar .CSV'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.accentPrimary,
                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Entendido / Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
