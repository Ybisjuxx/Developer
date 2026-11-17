import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

bool usuarioTienePermisoInventario() {
  final rol = AuthService.currentUser.rol.toUpperCase().trim();
  return rol == 'ADMINISTRADOR' || rol == 'RESPONSABLE_SANITARIO';
}

void verificarPermisoOAlertar(BuildContext context, VoidCallback accionPermitida) {
  if (usuarioTienePermisoInventario()) {
    accionPermitida();
  } else {
    final ts = ThemeService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.gpp_bad, color: ts.neonRed, size: 48),
        title: const Text('Acceso Restringido'),
        content: Text(
          'El usuario actual (${AuthService.currentUser.nombreCompleto}) tiene rol de CAJERO.\n\n'
          'Por políticas de seguridad y control interno, solo los roles de ADMINISTRADOR '
          'o RESPONSABLE SANITARIO están autorizados para ajustar piezas o dar de baja lotes en inventario.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Comprendido'),
          ),
        ],
      ),
    );
  }
}

void mostrarDialogoAjustarPiezasLote(
  BuildContext context, {
  required dynamic producto,
  required dynamic lote,
  required VoidCallback onSuccess,
}) {
  verificarPermisoOAlertar(context, () {
    final ts = ThemeService.instance;
    final stockCtrl = TextEditingController(text: (lote['stock_actual'] ?? 0).toString());
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: ts.accentPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ajustar Piezas - Lote ${lote["numero_lote"]}'),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Producto: ${producto["nombre_comercial"]} (${producto["sustancia_activa"]})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Caducidad: ${lote["fecha_caducidad"]} • Stock Actual: ${lote["stock_actual"]} pzas'),
              const SizedBox(height: 14),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nuevo Stock Físico (Piezas) *',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo del Ajuste de Inventario *',
                  hintText: 'Ej. Conteo físico, rotura accidental, aclaración...',
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            onPressed: () async {
              final nuevoStock = int.tryParse(stockCtrl.text.trim());
              final motivo = motivoCtrl.text.trim();
              if (nuevoStock == null || nuevoStock < 0 || motivo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese un stock válido y el motivo del ajuste.')),
                );
                return;
              }

              try {
                await ApiService.ajustarStockLote(
                  lote['id'],
                  nuevoStock: nuevoStock,
                  motivo: motivo,
                  usuario: AuthService.currentUser.nombreCompleto,
                  rolUsuario: AuthService.currentUser.rol,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onSuccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock del Lote ${lote["numero_lote"]} ajustado a $nuevoStock pzas.'),
                      backgroundColor: ts.neonGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
                  );
                }
              }
            },
            child: const Text('Aplicar Ajuste'),
          ),
        ],
      ),
    );
  });
}

void mostrarDialogoDarDeBajaLote(
  BuildContext context, {
  required dynamic producto,
  required dynamic lote,
  required VoidCallback onSuccess,
}) {
  verificarPermisoOAlertar(context, () {
    final ts = ThemeService.instance;
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: ts.neonRed, size: 44),
        title: Text('Dar de Baja Lote ${lote["numero_lote"]}'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ts.tintBg(ts.neonRed),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ts.neonRed.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'ATENCIÓN: Esta acción dará de baja el lote completo, fijando su stock en cero y generando una salida inmutable de auditoría en el Kardex.',
                  style: TextStyle(fontSize: 12, color: ts.neonRed, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text('Producto: ${producto["nombre_comercial"]}'),
              Text('Stock a liquidar: ${lote["stock_actual"]} piezas'),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Justificación / Motivo Sanitario de la Baja *',
                  hintText: 'Ej. Deterioro físico, sospecha de contaminación, caducado...',
                  prefixIcon: Icon(Icons.report_problem),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ts.neonRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final motivo = motivoCtrl.text.trim();
              if (motivo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Debe especificar el motivo de la baja.')),
                );
                return;
              }

              try {
                await ApiService.darDeBajaLote(
                  lote['id'],
                  motivo: motivo,
                  usuario: AuthService.currentUser.nombreCompleto,
                  rolUsuario: AuthService.currentUser.rol,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onSuccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lote ${lote["numero_lote"]} dado de baja con éxito.'),
                      backgroundColor: ts.neonRed,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
                  );
                }
              }
            },
            child: const Text('Confirmar Baja Definitiva'),
          ),
        ],
      ),
    );
  });
}

void mostrarDialogoComentarKardex(
  BuildContext context, {
  required dynamic movimiento,
  required VoidCallback onSuccess,
}) {
  final ts = ThemeService.instance;
  final obsCtrl = TextEditingController(text: movimiento['observaciones_auditoria'] ?? '');
  bool esIrregular = movimiento['es_irregular'] ?? false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.comment_bank, color: ts.accentPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Auditoría de Movimiento #${movimiento["id"]}'),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ts.surfaceAltBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ts.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo: ${movimiento["tipo_movimiento"]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Lote ID: ${movimiento["lote_id"]} • Cantidad: ${movimiento["cantidad"]} pzas'),
                      Text('Saldo: ${movimiento["stock_anterior"]} -> ${movimiento["stock_posterior"]} pzas'),
                      if (movimiento['motivo'] != null)
                        Text('Motivo original: ${movimiento["motivo"]}', style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  title: Text(
                    'Marcar como irregular / fuera de lugar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.neonRed),
                  ),
                  subtitle: Text(
                    'Identifica posibles faltantes no justificados, inconsistencias o mermas dudosas.',
                    style: TextStyle(fontSize: 11, color: ts.textSecondary),
                  ),
                  value: esIrregular,
                  activeColor: ts.neonRed,
                  onChanged: (val) {
                    setDialogState(() => esIrregular = val ?? false);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comentarios / Observaciones de Auditoría *',
                    hintText: 'Describe qué anomalía se detectó en este movimiento...',
                    prefixIcon: Icon(Icons.rate_review),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar Auditoría'),
            style: FilledButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            onPressed: () async {
              final obs = obsCtrl.text.trim();
              if (obs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese una observación o justificación.')),
                );
                return;
              }

              try {
                await ApiService.agregarObservacionKardex(
                  movimiento['id'],
                  observaciones: obs,
                  esIrregular: esIrregular,
                  usuarioAuditor: AuthService.currentUser.nombreCompleto,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onSuccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Observación de auditoría registrada en el Kardex.'),
                      backgroundColor: ts.accentPrimary,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: ts.neonRed),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}
