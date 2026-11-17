import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import 'chip_metadato_lote.dart';
import 'lote_acciones_dialogs.dart';

class CaducidadesTab extends StatefulWidget {
  final List<dynamic> lotesCaducidades;
  final List<dynamic> productos;
  final VoidCallback onReload;

  const CaducidadesTab({
    super.key,
    required this.lotesCaducidades,
    required this.productos,
    required this.onReload,
  });

  @override
  State<CaducidadesTab> createState() => _CaducidadesTabState();
}

class _CaducidadesTabState extends State<CaducidadesTab> with AutomaticKeepAliveClientMixin {
  String _filtroCaducidad = 'TODOS';
  String _busquedaCaducidad = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ts = ThemeService.instance;
    if (widget.lotesCaducidades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: ts.neonGreen, size: 64),
            const SizedBox(height: 14),
            const Text(
              'No hay lotes con riesgo de caducidad en los próximos 90 días',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el inventario activo cumple los márgenes de seguridad sanitaria de COFEPRIS.',
              style: TextStyle(color: ts.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ts.accentPrimary,
                foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
              ),
              onPressed: widget.onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar Análisis'),
            ),
          ],
        ),
      );
    }

    final lotesFiltrados = widget.lotesCaducidades.where((l) {
      if (_filtroCaducidad != 'TODOS') {
        if (l['urgencia'] != _filtroCaducidad) return false;
      }
      if (_busquedaCaducidad.isNotEmpty) {
        final q = _busquedaCaducidad.toLowerCase();
        final nom = (l['nombre_comercial'] ?? '').toString().toLowerCase();
        final sust = (l['sustancia_activa'] ?? '').toString().toLowerCase();
        final numL = (l['numero_lote'] ?? '').toString().toLowerCase();
        final lab = (l['laboratorio_fabricante'] ?? l['laboratorio_producto'] ?? '').toString().toLowerCase();
        if (!nom.contains(q) && !sust.contains(q) && !numL.contains(q) && !lab.contains(q)) return false;
      }
      return true;
    }).toList();

    final int criticos = widget.lotesCaducidades.where((l) => l['urgencia'] == 'CRITICA').length;
    final int preventivos = widget.lotesCaducidades.where((l) => l['urgencia'] == 'PREVENTIVA').length;
    final int caducados = widget.lotesCaducidades.where((l) => l['urgencia'] == 'CADUCADO').length;
    final int piezasRiesgo = widget.lotesCaducidades.fold<int>(0, (sum, l) => sum + (l['stock_actual'] as int? ?? 0));

    final Color bannerColor = criticos > 0 ? ts.neonRed : ts.neonAmber;

    return Column(
      children: [
        // Banner Superior Informativo de Alertas FEFO HeroUI
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ts.tintBg(bannerColor),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bannerColor.withValues(alpha: 0.4), width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: LayoutBuilder(
              builder: (context, bConstraints) {
                final isNarrow = bConstraints.maxWidth < 650;
                final iconAndText = Row(
                  children: [
                    Icon(
                      criticos > 0 ? Icons.alarm_on : Icons.warning_amber_rounded,
                      color: bannerColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monitoreo Sanitario de Caducidades (Prioridad FEFO)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: bannerColor,
                            ),
                          ),
                          Text(
                            '${widget.lotesCaducidades.length} lotes detectados ($piezasRiesgo piezas en anaquel). Surtir prioritariamente antes de caducar.',
                            style: TextStyle(fontSize: 12, color: ts.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final refreshBtn = FilledButton.tonalIcon(
                  onPressed: widget.onReload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      iconAndText,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: refreshBtn),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: iconAndText),
                      const SizedBox(width: 12),
                      refreshBtn,
                    ],
                  );
                }
              },
            ),
          ),
        ),

        // Filtros y Búsqueda de Lotes por Caducar HeroUI
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ts.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ts.borderColor, width: 1.2),
              boxShadow: ts.cardGlowShadow,
            ),
            child: LayoutBuilder(
              builder: (context, fConstraints) {
                final isNarrow = fConstraints.maxWidth < 650;
                final searchField = TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Filtrar por medicamento, sustancia o lote...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _busquedaCaducidad.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _busquedaCaducidad = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _busquedaCaducidad = val.trim()),
                );

                final chips = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${widget.lotesCaducidades.length})'),
                        selected: _filtroCaducidad == 'TODOS',
                        selectedColor: ts.tintBg(ts.accentPrimary),
                        onSelected: (_) => setState(() => _filtroCaducidad = 'TODOS'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(Icons.alarm, color: ts.neonRed, size: 16),
                        label: Text('Críticos <= 30d ($criticos)'),
                        selected: _filtroCaducidad == 'CRITICA',
                        selectedColor: ts.tintBg(ts.neonRed),
                        onSelected: (_) => setState(() => _filtroCaducidad = 'CRITICA'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(Icons.schedule, color: ts.neonAmber, size: 16),
                        label: Text('Preventivos ($preventivos)'),
                        selected: _filtroCaducidad == 'PREVENTIVA',
                        selectedColor: ts.tintBg(ts.neonAmber),
                        onSelected: (_) => setState(() => _filtroCaducidad = 'PREVENTIVA'),
                      ),
                      if (caducados > 0) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: Icon(Icons.block, color: ts.neonPurple, size: 16),
                          label: Text('Caducados ($caducados)'),
                          selected: _filtroCaducidad == 'CADUCADO',
                          selectedColor: ts.tintBg(ts.neonPurple),
                          onSelected: (_) => setState(() => _filtroCaducidad = 'CADUCADO'),
                        ),
                      ],
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      chips,
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(flex: 4, child: searchField),
                      const SizedBox(width: 12),
                      Expanded(flex: 6, child: chips),
                    ],
                  );
                }
              },
            ),
          ),
        ),
        const Divider(height: 1),

        // Listado de Tarjetas de Lotes Próximos a Vencer
        Expanded(
          child: lotesFiltrados.isEmpty
              ? const Center(child: Text('No hay lotes que coincidan con los filtros seleccionados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lotesFiltrados.length,
                  itemBuilder: (context, index) {
                    final lote = lotesFiltrados[index];
                    return _buildTarjetaLoteCaducidad(lote);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTarjetaLoteCaducidad(dynamic lote) {
    final ts = ThemeService.instance;
    final urgencia = lote['urgencia'] as String? ?? 'PREVENTIVA';
    final int dias = lote['dias_restantes'] as int? ?? 0;
    final int stock = lote['stock_actual'] as int? ?? 0;

    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;
    String badgeTexto;

    if (urgencia == 'CADUCADO' || dias < 0) {
      badgeBg = ts.tintBg(ts.neonPurple);
      badgeFg = ts.neonPurple;
      badgeIcon = Icons.block;
      badgeTexto = 'PRODUCTO CADUCADO (Hace ${dias.abs()} días)';
    } else if (urgencia == 'CRITICA' || dias <= 30) {
      badgeBg = ts.tintBg(ts.neonRed);
      badgeFg = ts.neonRed;
      badgeIcon = Icons.error_outline;
      badgeTexto = 'CRÍTICO: Vence en $dias días (Despachar Ya)';
    } else {
      badgeBg = ts.tintBg(ts.neonAmber);
      badgeFg = ts.neonAmber;
      badgeIcon = Icons.access_time;
      badgeTexto = 'PREVENTIVO: Vence en $dias días';
    }

    // Buscar el producto padre completo si está cargado
    final prodId = lote['producto_id'] as int?;
    final productoPadre = widget.productos.firstWhere(
      (p) => p['id'] == prodId,
      orElse: () => {
        'id': prodId,
        'nombre_comercial': lote['nombre_comercial'],
        'sustancia_activa': lote['sustancia_activa'],
        'presentacion': lote['presentacion'],
        'laboratorio': lote['laboratorio_producto'],
      },
    );

    final Map<String, dynamic> loteAdaptado = {
      'id': lote['lote_id'],
      'numero_lote': lote['numero_lote'],
      'fecha_caducidad': lote['fecha_caducidad'],
      'stock_actual': lote['stock_actual'],
      'costo_unitario': lote['costo_unitario'],
      'activo': true,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgencia == 'CRITICA' ? ts.neonRed : ts.borderColor,
          width: urgencia == 'CRITICA' ? 1.6 : 1.2,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Producto y Badge de Urgencia
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lote['nombre_comercial'] ?? 'Medicamento',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ts.surfaceAltBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ts.borderColor),
                          ),
                          child: Text(
                            '${lote["grupo_farmacopea"] ?? "GRUPO_VI"}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ts.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lote["sustancia_activa"]} • ${lote["presentacion"]}',
                      style: TextStyle(color: ts.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeFg.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeFg, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        badgeTexto,
                        style: TextStyle(color: badgeFg, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadatos del Lote (Sub-Agente 2)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChipMetadatoLote(icon: Icons.qr_code, texto: 'Lote: ${lote["numero_lote"]}', color: ts.accentPrimary),
                ChipMetadatoLote(icon: Icons.event_busy, texto: 'Caduca: ${lote["fecha_caducidad"]}', color: ts.neonRed),
                if (lote['laboratorio_fabricante'] != null)
                  ChipMetadatoLote(icon: Icons.factory, texto: 'Lab: ${lote["laboratorio_fabricante"]}', color: ts.neonBlue),
                if (lote['forma_farmaceutica'] != null)
                  ChipMetadatoLote(icon: Icons.medication, texto: 'Forma: ${lote["forma_farmaceutica"]}', color: ts.neonPurple),
                if (lote['dosificacion'] != null)
                  ChipMetadatoLote(icon: Icons.scale, texto: 'Dosis: ${lote["dosificacion"]}', color: ts.accentPrimary),
                if (lote['fecha_ingreso'] != null)
                  ChipMetadatoLote(icon: Icons.input, texto: 'Ingreso: ${lote["fecha_ingreso"]}', color: ts.neonAmber),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Existencias y Acciones de Control
            LayoutBuilder(
              builder: (context, cConstraints) {
                final bool isNarrow = cConstraints.maxWidth < 650;
                final infoRow = Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Existencia en anaquel:', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        Text(
                          '$stock piezas disponibles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: stock > 0 ? ts.neonGreen : ts.neonRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precio al público:', style: TextStyle(fontSize: 11, color: ts.textSecondary)),
                        Text(
                          '\$${lote["precio_venta"]} MXN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                );

                final actionBtns = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Ajustar Stock', style: TextStyle(fontSize: 11)),
                      onPressed: () => mostrarDialogoAjustarPiezasLote(
                        context,
                        producto: productoPadre,
                        lote: loteAdaptado,
                        onSuccess: widget.onReload,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.tintBg(ts.neonRed),
                        foregroundColor: ts.neonRed,
                      ),
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Baja', style: TextStyle(fontSize: 11)),
                      onPressed: () => mostrarDialogoDarDeBajaLote(
                        context,
                        producto: productoPadre,
                        lote: loteAdaptado,
                        onSuccess: widget.onReload,
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoRow,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actionBtns),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      infoRow,
                      const Spacer(),
                      actionBtns,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
