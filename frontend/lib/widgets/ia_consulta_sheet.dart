import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'premium_ui.dart';

  void showConsultaIaModal(BuildContext context, {void Function(int)? onNavigate}) {
    final TextEditingController chatController = TextEditingController();
    final ScrollController scrollController = ScrollController();
    final List<Map<String, dynamic>> conversacion = [
      {
        'remitente': 'ia',
        'texto':
            '¡Hola! Soy tu **Asistente Farmacéutico IA** de FarmaControl.\n\n'
            'Puedo verificar si tenemos un medicamento en stock o buscar **sustitutos bioequivalentes y alternativas terapéuticas** en nuestro catálogo si no está disponible.',
        'sustitutos': <dynamic>[],
        'aviso': null,
      }
    ];
    bool esperandoIa = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setChatState) {
          final isWide = MediaQuery.of(context).size.width > 700;

          void enviarConsulta([String? textoDirecto]) async {
            final query = (textoDirecto ?? chatController.text).trim();
            if (query.isEmpty || esperandoIa) return;

            chatController.clear();
            setChatState(() {
              conversacion.add({
                'remitente': 'usuario',
                'texto': query,
                'sustitutos': <dynamic>[],
                'aviso': null,
              });
              esperandoIa = true;
            });

            try {
              final res = await ApiService.consultarIaMedicamentos(query);
              setChatState(() {
                conversacion.add({
                  'remitente': 'ia',
                  'texto': res['respuesta_ia'] ?? 'Análisis farmacológico completado.',
                  'sustitutos': res['sustitutos_en_stock'] ?? <dynamic>[],
                  'aviso': res['aviso_sanitario'],
                });
                esperandoIa = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                }
              });
            } catch (e) {
              setChatState(() {
                conversacion.add({
                  'remitente': 'ia',
                  'texto': '⚠️ No se pudo procesar la consulta con el motor IA: $e',
                  'sustitutos': <dynamic>[],
                  'aviso': null,
                });
                esperandoIa = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: ThemeService.instance.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ThemeService.instance.borderColor),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeService.instance.tintBg(ThemeService.instance.accentPrimary),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ThemeService.instance.accentPrimary.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.smart_toy, color: ThemeService.instance.accentPrimary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente Farmacéutico IA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        'Búsqueda de medicamentos, bioequivalencia y sustitutos en stock',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: isWide ? 620 : double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Sugerencias rápidas de consulta
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipSugerencia('¿Tempra o Paracetamol?', () => enviarConsulta('Tempra')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Sustitutos de Amoxicilina?', () => enviarConsulta('Sustitutos de Amoxicilina')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Antihistamínico para alergia?', () => enviarConsulta('Antihistamínico para alergia')),
                        const SizedBox(width: 6),
                        _chipSugerencia('¿Alternativas a Flanax / Naproxeno?', () => enviarConsulta('Alternativas a Flanax')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Área de mensajes del chat
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: conversacion.length + (esperandoIa ? 1 : 0),
                      itemBuilder: (context, idx) {
                        if (idx == conversacion.length && esperandoIa) {
                          return AnimatedFadeSlideIn(
                            duration: const Duration(milliseconds: 250),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Analizando catálogo de farmacia y bioequivalencia...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ThemeService.instance.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final ts = ThemeService.instance;
                        final msg = conversacion[idx];
                        final bool esUsuario = msg['remitente'] == 'usuario';
                        final List sustitutos = msg['sustitutos'] ?? [];
                        final String? aviso = msg['aviso'];
                        final Color userBubbleBg = ts.esOscuro ? ts.tintBg(ts.accentPrimary, darkAlpha: 0.24) : ts.headerBg;
                        final Color userBubbleFg = ts.esOscuro ? ts.textPrimary : Colors.white;

                        return AnimatedFadeSlideIn(
                          duration: const Duration(milliseconds: 280),
                          child: Align(
                            alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(maxWidth: isWide ? 520 : 340),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: esUsuario ? userBubbleBg : ts.surfaceAltBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: esUsuario ? const Radius.circular(14) : Radius.zero,
                                  bottomRight: esUsuario ? Radius.zero : const Radius.circular(14),
                                ),
                                border: Border.all(
                                  color: esUsuario ? ts.accentPrimary : ts.borderColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        esUsuario ? Icons.person : Icons.smart_toy,
                                        size: 14,
                                        color: esUsuario ? userBubbleFg.withValues(alpha: 0.8) : ts.accentPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        esUsuario ? 'Tú (Farmacéutico)' : 'Asistente IA',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: esUsuario ? userBubbleFg.withValues(alpha: 0.85) : ts.accentPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    msg['texto'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: esUsuario ? userBubbleFg : ts.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),

                                  // Tarjetas de sustitutos en stock directo
                                  if (sustitutos.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      '📦 Fármacos disponibles en inventario:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ts.textPrimary),
                                    ),
                                    const SizedBox(height: 6),
                                    ...sustitutos.map((s) {
                                      final String tipo = (s["tipo_sustitucion"] ?? '').toString();
                                      final Color accentColor = switch (tipo) {
                                        'INTERCAMBIABLE' || 'BIOEQUIVALENTE_DIRECTO' => ts.neonGreen,
                                        'MISMA_SUSTANCIA_OTRA_PRESENTACION' || 'MISMA_FAMILIA_TERAPEUTICA' => ts.neonAmber,
                                        'CONSULTAR_MEDICO' || 'COINCIDENCIA_INDICACION' => ts.neonRed,
                                        _ => ts.accentPrimary,
                                      };
                                      final String tipoLabel = switch (tipo) {
                                        'INTERCAMBIABLE' || 'BIOEQUIVALENTE_DIRECTO' => '🟢 INTERCAMBIABLE',
                                        'MISMA_SUSTANCIA_OTRA_PRESENTACION' || 'MISMA_FAMILIA_TERAPEUTICA' => '🟡 MISMA SUSTANCIA (OTRA PRESENTACIÓN)',
                                        'CONSULTAR_MEDICO' || 'COINCIDENCIA_INDICACION' => '🔴 CONSULTAR MÉDICO',
                                        _ => tipo.replaceAll('_', ' '),
                                      };
                                      final int stock = (s["stock_disponible"] is num)
                                          ? (s["stock_disponible"] as num).toInt()
                                          : 0;
                                      final double stockFactor = (stock / 25.0).clamp(0.08, 1.0);
                                      final Color stockColor = stock > 5
                                          ? ts.neonGreen
                                          : (stock > 0 ? ts.neonAmber : ts.neonRed);

                                      final rawAdv = s['advertencias'];
                                      final List<String> advertencias = (rawAdv is List)
                                          ? rawAdv.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
                                          : <String>[];
                                      final String motivo = (s["motivo_sugerencia"] ?? '').toString().trim();
                                      final String indicacion = (s["indicacion_terapeutica"] ?? '').toString().trim();
                                      final bool esConsultaMedica = tipo == 'CONSULTAR_MEDICO' || tipo == 'COINCIDENCIA_INDICACION';
                                      final String botonTexto = switch (tipo) {
                                        'CONSULTAR_MEDICO' || 'COINCIDENCIA_INDICACION' => 'Consultar con médico',
                                        'MISMA_SUSTANCIA_OTRA_PRESENTACION' || 'MISMA_FAMILIA_TERAPEUTICA' => 'Confirmar en POS',
                                        'INTERCAMBIABLE' || 'BIOEQUIVALENTE_DIRECTO' => 'Ir al POS',
                                        _ => 'Ir al POS',
                                      };

                                      return AnimatedHoverScaleCard(
                                        hoverScale: 1.02,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: ts.cardBg,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: accentColor.withValues(alpha: ts.esTemaNeon ? 0.45 : 0.28),
                                              width: 1.2,
                                            ),
                                            boxShadow: ts.cardGlowShadow,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                    color: accentColor,
                                                    width: 5,
                                                  ),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(9),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                          Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      '${s["nombre_comercial"]} (${s["sustancia_activa"]})',
                                                                      style: TextStyle(
                                                                        fontWeight: FontWeight.bold,
                                                                        fontSize: 12,
                                                                        color: ts.textPrimary,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '${s["presentacion"]} • Lab: ${s["laboratorio"]}',
                                                                      style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              if (tipoLabel.isNotEmpty)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: accentColor.withValues(alpha: ts.esOscuro ? 0.18 : 0.12),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                    border: Border.all(
                                                                      color: accentColor.withValues(alpha: 0.4),
                                                                      width: 0.8,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    tipoLabel,
                                                                    style: TextStyle(
                                                                      fontSize: 9.5,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: accentColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          if (motivo.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 3),
                                                              child: Text(
                                                                '💡 $motivo',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: ts.neonBlue,
                                                                  fontStyle: FontStyle.italic,
                                                                ),
                                                              ),
                                                            )
                                                          else if (indicacion.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 3),
                                                              child: Text(
                                                                '💡 $indicacion',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: ts.neonBlue,
                                                                  fontStyle: FontStyle.italic,
                                                                ),
                                                              ),
                                                            ),
                                                          if (advertencias.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 4),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: advertencias.map((adv) {
                                                                  return Padding(
                                                                    padding: const EdgeInsets.only(bottom: 2),
                                                                    child: Text(
                                                                      '⚠️ $adv',
                                                                      style: TextStyle(
                                                                        fontSize: 11,
                                                                        color: ts.neonAmber,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ),
                                                          if (s['visible_para_cajero'] == false)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                '🔒 Restringido para cajero • Requiere validación médica/farmacéutica',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: ts.neonRed,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(height: 6),
                                                          Wrap(
                                                            alignment: WrapAlignment.spaceBetween,
                                                            crossAxisAlignment: WrapCrossAlignment.center,
                                                            spacing: 8,
                                                            runSpacing: 6,
                                                            children: [
                                                              Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    'Stock: $stock pzas',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: stockColor,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  SizedBox(
                                                                    width: 58,
                                                                    child: AnimatedBulletBar(
                                                                      value: stockFactor,
                                                                      height: 5,
                                                                      color: stockColor,
                                                                      borderRadius: BorderRadius.circular(3),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Text(
                                                                    '• \$${s["precio_venta"]} MXN',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: ts.accentPrimary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              FilledButton.tonal(
                                                                style: FilledButton.styleFrom(
                                                                  backgroundColor: esConsultaMedica
                                                                      ? ts.neonRed.withValues(alpha: 0.15)
                                                                      : null,
                                                                  foregroundColor: esConsultaMedica
                                                                      ? ts.neonRed
                                                                      : null,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                                  visualDensity: VisualDensity.compact,
                                                                ),
                                                                onPressed: () {
                                                                  if (esConsultaMedica) {
                                                                    showDialog(
                                                                      context: ctx,
                                                                      builder: (dialogCtx) => AlertDialog(
                                                                        backgroundColor: ts.cardBg,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(14),
                                                                          side: BorderSide(color: ts.borderColor),
                                                                        ),
                                                                        title: Row(
                                                                          children: [
                                                                            Icon(Icons.medical_services_outlined, color: ts.neonRed),
                                                                            const SizedBox(width: 8),
                                                                            const Expanded(
                                                                              child: Text(
                                                                                'Consulta con Médico Requerida',
                                                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        content: Column(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              'El medicamento "${s["nombre_comercial"]}" es una alternativa terapéutica y no debe sustituirse directamente en caja.',
                                                                              style: TextStyle(fontSize: 13, color: ts.textPrimary),
                                                                            ),
                                                                            const SizedBox(height: 10),
                                                                            Text(
                                                                              '⚠️ Por normativa sanitaria (COFEPRIS), cualquier cambio de principio activo o formulación controlada debe ser prescrito o autorizado expresamente por el médico tratante o evaluado por el responsable sanitario / profesional farmacéutico.',
                                                                              style: TextStyle(fontSize: 12, color: ts.textSecondary),
                                                                            ),
                                                                            if (advertencias.isNotEmpty) ...[
                                                                              const SizedBox(height: 10),
                                                                              const Text(
                                                                                'Advertencias clínicas registradas:',
                                                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                                              ),
                                                                              const SizedBox(height: 4),
                                                                              ...advertencias.map(
                                                                                (adv) => Padding(
                                                                                  padding: const EdgeInsets.only(bottom: 2),
                                                                                  child: Text('• $adv', style: TextStyle(fontSize: 11, color: ts.neonAmber)),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ],
                                                                        ),
                                                                        actions: [
                                                                          FilledButton(
                                                                            style: FilledButton.styleFrom(
                                                                              backgroundColor: ts.neonRed,
                                                                              foregroundColor: Colors.white,
                                                                            ),
                                                                            onPressed: () => Navigator.of(dialogCtx).pop(),
                                                                            child: const Text('Entendido'),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    );

                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      SnackBar(
                                                                        content: Text(
                                                                          '⚠️ Consulta médica requerida: "${s["nombre_comercial"]}" debe ser autorizado por el médico tratante o farmacéutico.',
                                                                        ),
                                                                        backgroundColor: Colors.red.shade900,
                                                                        duration: const Duration(seconds: 4),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    Navigator.of(ctx).pop();
                                                                    onNavigate?.call(1); // Ir a Punto de Venta
                                                                  }
                                                                },
                                                                child: Text(botonTexto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          );
                                    }),
                                  ],

                                  // Aviso Sanitario COFEPRIS
                                  if (aviso != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: Text(
                                        aviso,
                                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Caja de entrada de consulta
                  Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            onSubmitted: (_) => enviarConsulta(),
                            decoration: const InputDecoration(
                              hintText: 'Pregunta por un fármaco o sustituto...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onPressed: esperandoIa ? null : () => enviarConsulta(),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('Consultar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chipSugerencia(String label, VoidCallback onTap) {
    return _ChipSugerenciaAnimated(label: label, onTap: onTap);
  }


class _ChipSugerenciaAnimated extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ChipSugerenciaAnimated({required this.label, required this.onTap});

  @override
  State<_ChipSugerenciaAnimated> createState() => _ChipSugerenciaAnimatedState();
}

class _ChipSugerenciaAnimatedState extends State<_ChipSugerenciaAnimated> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: ActionChip(
          avatar: Icon(Icons.bubble_chart, size: 14, color: ts.accentPrimary),
          label: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: _isHovered ? FontWeight.w600 : FontWeight.normal,
              color: _isHovered ? ts.accentPrimary : ts.textPrimary,
            ),
          ),
          onPressed: widget.onTap,
          backgroundColor: _isHovered
              ? ts.accentPrimary.withValues(alpha: ts.esOscuro ? 0.22 : 0.14)
              : (ts.esOscuro ? ts.surfaceAltBg : Colors.teal.shade50),
          side: BorderSide(
            color: _isHovered
                ? ts.accentPrimary
                : (ts.esOscuro ? ts.borderColor : Colors.teal.shade200),
          ),
        ),
      ),
    );
  }
}
