import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

void showClienteDetalleDialog({
  required BuildContext context,
  required Map<String, dynamic> cliente,
  required VoidCallback onEdit,
}) {
  final ts = ThemeService.instance;
  showDialog(
    context: context,
    builder: (ctx) {
      final List enfermedades = cliente['enfermedades'] ?? [];
      return AlertDialog(
        backgroundColor: ts.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: ts.esOscuro ? BorderSide(color: ts.borderColor) : BorderSide.none,
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: ts.accentPrimary,
              child: Icon(Icons.person, color: ts.esTemaNeon ? Colors.black : Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cliente['nombre']} ${cliente['apellido']}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ts.textPrimary),
                  ),
                  Text(
                    'Cliente Lealtad • ${cliente['descuento_porcentaje']}% Descuento en Compras',
                    style: TextStyle(fontSize: 12, color: ts.accentPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(ctx).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: ts.borderColor),
                _infoItem(Icons.phone, 'Teléfono', cliente['telefono'] ?? 'No especificado'),
                _infoItem(Icons.email, 'Correo', cliente['correo_electronico'] ?? 'No especificado'),
                _infoItem(Icons.location_on, 'Dirección', cliente['direccion'] ?? 'No especificada'),
                _infoItem(Icons.wc, 'Sexo / Género', cliente['sexo'] ?? 'No especificado'),
                _infoItem(Icons.cake, 'Fecha de Nacimiento', cliente['fecha_nacimiento'] ?? 'No especificada'),
                const SizedBox(height: 12),
                // Sub-Agente 1: Seguimiento de Padecimientos Crónicos y Resurtimiento
                if (cliente['tiene_padecimientos_cronicos'] == true) ...[
                  Builder(
                    builder: (ctx) {
                      final int? dias = cliente['dias_para_resurtimiento'] as int?;
                      final bool alerta = cliente['alerta_resurtimiento_activa'] == true;
                      final bool vencido = dias != null && dias < 0;
                      final String medStr = cliente['medicamento_cronico_principal'] ?? 'Tratamiento crónico';
                      final medsList = medStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

                      Color headerColor = ts.tintBg(ts.neonGreen);
                      Color statusBorderColor = ts.neonGreen.withValues(alpha: 0.45);
                      Color textColor = ts.neonGreen;
                      IconData icon = Icons.check_circle_outline;
                      String statusTitle = '🟢 Tratamiento al Día';

                      if (vencido) {
                        headerColor = ts.tintBg(ts.neonRed);
                        statusBorderColor = ts.neonRed.withValues(alpha: 0.45);
                        textColor = ts.neonRed;
                        icon = Icons.error_outline;
                        statusTitle = '🚨 Resurtimiento Vencido hace ${dias.abs()} días';
                      } else if (alerta) {
                        headerColor = ts.tintBg(ts.neonAmber);
                        statusBorderColor = ts.neonAmber.withValues(alpha: 0.45);
                        textColor = ts.neonAmber;
                        icon = Icons.alarm_on;
                        statusTitle = '⚠️ Alerta de Resurtimiento Activa (${dias ?? 0} días restantes)';
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: headerColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: textColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    statusTitle,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Medicamentos Crónicos Prescritos:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.textSecondary)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: medsList.map((m) {
                                return Chip(
                                  avatar: Icon(Icons.medication, size: 14, color: ts.esTemaNeon ? Colors.black : Colors.white),
                                  backgroundColor: ts.accentPrimary,
                                  label: Text(m, style: TextStyle(color: ts.esTemaNeon ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Suministro: ${cliente["dias_tratamiento"] ?? 30} días  •  Última Visita: ${cliente["ultima_visita"] != null ? cliente["ultima_visita"].toString().replaceFirst("T", " ").substring(0, 16) : "Sin registrar"}',
                              style: TextStyle(fontSize: 11, color: ts.textPrimary),
                            ),
                            if (cliente['fecha_proximo_resurtimiento'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Fecha Meta de Resurtimiento: ${cliente["fecha_proximo_resurtimiento"]}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ts.textPrimary),
                              ),
                            ],
                            if (cliente['mensaje_alerta_resurtimiento'] != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ts.surfaceBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorderColor),
                                ),
                                child: Text(
                                  cliente['mensaje_alerta_resurtimiento'],
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Historial Clínico (Diagnósticos CIE-11):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                ),
                const SizedBox(height: 6),
                if (enfermedades.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ts.surfaceBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ts.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety_outlined, color: ts.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text('Sin padecimientos crónicos registrados.', style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: enfermedades.map((enf) {
                      return Chip(
                        avatar: Icon(Icons.medical_services, size: 16, color: ts.accentPrimary),
                        backgroundColor: ts.surfaceAltBg,
                        side: BorderSide(color: ts.borderColor),
                        label: Text(
                          '${enf['codigo_cie']} - ${enf['descripcion']}',
                          style: TextStyle(color: ts.textPrimary, fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                if (cliente['notas_clinicas'] != null && (cliente['notas_clinicas'] as String).isNotEmpty) ...[
                  Text(
                    'Notas Médicas y Farmacéuticas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ts.tintBg(ts.neonAmber),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ts.neonAmber.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      cliente['notas_clinicas'],
                      style: TextStyle(fontSize: 12, color: ts.textPrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ts.accentPrimary),
            onPressed: () {
              Navigator.of(ctx).pop();
              onEdit();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 4),
                Text('Editar Cliente'),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ts.accentPrimary,
              foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}

Widget _infoItem(IconData icon, String label, String value) {
  final ts = ThemeService.instance;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: ts.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ts.textPrimary)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: ts.textPrimary))),
      ],
    ),
  );
}
