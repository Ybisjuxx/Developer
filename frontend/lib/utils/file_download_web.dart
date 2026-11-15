// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Dispara la descarga directa de un archivo de texto en navegador web.
Future<String?> descargarArchivoTexto(
  String nombreArchivo,
  String contenido, {
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  // Se antepone BOM UTF-8 para que Excel reconozca acentos correctamente.
  final bytes = utf8.encode('\uFEFF$contenido');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return nombreArchivo;
}
