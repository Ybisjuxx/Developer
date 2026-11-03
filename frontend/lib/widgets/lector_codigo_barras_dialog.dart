import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LectorCodigoBarrasDialog extends StatefulWidget {
  final String titulo;

  const LectorCodigoBarrasDialog({
    super.key,
    this.titulo = 'Escanear Código de Barras',
  });

  /// Muestra el escáner de cámara en un diálogo responsivo o pantalla completa en móvil
  static Future<String?> escanear(BuildContext context, {String titulo = 'Escanear Código de Barras'}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LectorCodigoBarrasDialog(titulo: titulo),
    );
  }

  @override
  State<LectorCodigoBarrasDialog> createState() => _LectorCodigoBarrasDialogState();
}

class _LectorCodigoBarrasDialogState extends State<LectorCodigoBarrasDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final TextEditingController _manualController = TextEditingController();
  bool _procesando = false;
  bool _mostrarManual = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_procesando) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final valor = barcode.rawValue;
      if (valor != null && valor.trim().isNotEmpty) {
        setState(() => _procesando = true);
        Navigator.of(context).pop(valor.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool esPantallaPequena = size.width < 600;

    return Dialog(
      insetPadding: esPantallaPequena
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: esPantallaPequena ? size.width * 0.95 : 480,
        height: esPantallaPequena ? size.height * 0.75 : 560,
        color: Colors.black,
        child: Stack(
          children: [
            // Vista de la cámara con MobileScanner
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off, color: Colors.amber, size: 54),
                          const SizedBox(height: 14),
                          const Text(
                            'No se pudo acceder a la cámara',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Asegúrate de conceder permisos de cámara en tu navegador móvil (HTTPS).\nDetalle: ${error.errorDetails?.message ?? error.errorCode.name}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.keyboard),
                            label: const Text('Ingresar Código Manualmente'),
                            onPressed: () => setState(() => _mostrarManual = true),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Visor / Marco de Enfoque con efecto de escáner
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: Center(
                    child: Container(
                      width: esPantallaPequena ? size.width * 0.72 : 300,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.tealAccent, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.tealAccent.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 2,
                            width: esPantallaPequena ? size.width * 0.65 : 270,
                            color: Colors.redAccent.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Apunta al código de barras del medicamento',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Barra Superior de Controles (Título, Linterna, Cambiar Cámara, Cerrar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Colors.tealAccent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Botón Linterna (Torch)
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                        tooltip: 'Linterna',
                        onPressed: () => _controller.toggleTorch(),
                      ),
                      // Botón Alternar Cámara Frontal / Trasera
                      IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 20),
                        tooltip: 'Cambiar Cámara',
                        onPressed: () => _controller.switchCamera(),
                      ),
                      // Botón Cerrar
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 22),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Barra Inferior con Entrada Manual Opcional
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: _mostrarManual
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Ingresa código manual...',
                                  hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    Navigator.of(context).pop(val.trim());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: () {
                                final val = _manualController.text.trim();
                                if (val.isNotEmpty) {
                                  Navigator.of(context).pop(val);
                                }
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        )
                      : Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.white70),
                            icon: const Icon(Icons.keyboard, size: 16),
                            label: const Text('¿Cámara no enfoca? Ingresar código manual', style: TextStyle(fontSize: 12)),
                            onPressed: () => setState(() => _mostrarManual = true),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
