import 'dart:convert';
import 'dart:io';

/// Guarda el archivo de texto en la carpeta de Descargas (o temporal) en escritorio/móvil.
Future<String?> descargarArchivoTexto(
  String nombreArchivo,
  String contenido, {
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  Directory destinoDir = Directory.systemTemp;
  if (home != null && home.isNotEmpty) {
    final sep = Platform.pathSeparator;
    final downloads = Directory('$home${sep}Downloads');
    if (await downloads.exists()) {
      destinoDir = downloads;
    }
  }
  final ruta = '${destinoDir.path}${Platform.pathSeparator}$nombreArchivo';
  final archivo = File(ruta);
  await archivo.writeAsBytes(utf8.encode('\uFEFF$contenido'), flush: true);
  return archivo.path;
}
