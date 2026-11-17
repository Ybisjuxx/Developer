import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/lector_codigo_barras_dialog.dart';
import '../../widgets/premium_ui.dart';
import 'chip_metadato_lote.dart';
import 'lote_acciones_dialogs.dart';

class ProductosTab extends StatefulWidget {
  final List<dynamic> productos;
  final VoidCallback onReload;

  const ProductosTab({
    super.key,
    required this.productos,
    required this.onReload,
  });

  @override
  State<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<ProductosTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _busquedaLotesController = TextEditingController();
  String _filtroGrupoLotes = 'TODOS';
  bool _soloConStockLotes = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _busquedaLotesController.dispose();
    super.dispose();
  }

  // Escaneo óptico de medicamento para búsqueda inmediata en almacén
  Future<void> _escanearCodigoParaInventario() async {
    final cod = await LectorCodigoBarrasDialog.escanear(
      context,
      titulo: 'Escanear Medicamento para Inventario',
    );
    if (cod != null && cod.trim().isNotEmpty) {
      setState(() {
        _busquedaLotesController.text = cod.trim();
      });
    }
  }

  // Filtrado reactivo del catálogo de lotes por texto y grupo terapéutico COFEPRIS
  List<dynamic> get _productosFiltrados {
    final query = _busquedaLotesController.text.trim().toLowerCase();

    return widget.productos.where((p) {
      // 1. Filtro por disponibilidad de stock
      final int stock = p['stock_total'] ?? 0;
      if (_soloConStockLotes && stock <= 0) {
        return false;
      }

      // 2. Filtro por Grupo Farmacopea / Terapéutico COFEPRIS (similar al mostrador POS)
      if (_filtroGrupoLotes != 'TODOS') {
        final grupo = (p['grupo_farmacopea'] ?? 'GRUPO_VI').toString().toUpperCase();
        if (_filtroGrupoLotes == 'CONTROLADOS') {
          if (!grupo.contains('GRUPO_I') && !grupo.contains('GRUPO_II') && !grupo.contains('GRUPO_III') && !grupo.contains('CONTROLADO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_IV') {
          if (!grupo.contains('GRUPO_IV') && !grupo.contains('ANTIBIOTICO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_V') {
          if (!grupo.contains('GRUPO_V') && !grupo.contains('CRONICO')) {
            return false;
          }
        } else if (_filtroGrupoLotes == 'GRUPO_VI') {
          if (!grupo.contains('GRUPO_VI') && !grupo.contains('LIBRE')) {
            return false;
          }
        } else if (grupo != _filtroGrupoLotes) {
          return false;
        }
      }

      // 3. Filtro por Búsqueda (Nombre Comercial, Sustancia Activa, Presentación, Laboratorio, Código o Lote)
      if (query.isNotEmpty) {
        final nom = (p['nombre_comercial'] ?? '').toString().toLowerCase();
        final sus = (p['sustancia_activa'] ?? '').toString().toLowerCase();
        final pre = (p['presentacion'] ?? '').toString().toLowerCase();
        final lab = (p['laboratorio'] ?? '').toString().toLowerCase();
        final cod = (p['codigo_barras'] ?? '').toString().toLowerCase();

        final lotes = (p['lotes'] as List<dynamic>? ?? []);
        final coincideLote = lotes.any((l) =>
            (l['numero_lote'] ?? '').toString().toLowerCase().contains(query) ||
            (l['laboratorio_fabricante'] ?? '').toString().toLowerCase().contains(query));

        if (!nom.contains(query) &&
            !sus.contains(query) &&
            !pre.contains(query) &&
            !lab.contains(query) &&
            !cod.contains(query) &&
            !coincideLote) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ts = ThemeService.instance;
    final productosVisibles = _productosFiltrados;

    return Column(
      children: [
        // Barra de Búsqueda y Clasificación por Grupo Terapéutico COFEPRIS HeroUI
        PremiumSurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Búsqueda con Cámara y Botón Limpiar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busquedaLotesController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por medicamento, sustancia, lote o escanea código...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: ts.surfaceBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ts.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ts.borderColor),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_busquedaLotesController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _busquedaLotesController.clear();
                                  setState(() {});
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.camera_alt, color: ts.accentPrimary),
                              tooltip: 'Escanear código de barras con la cámara',
                              onPressed: _escanearCodigoParaInventario,
                            ),
                          ],
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chips de Clasificación Sanitaria COFEPRIS (similar al mostrador POS)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${widget.productos.length})'),
                      selected: _filtroGrupoLotes == 'TODOS',
                      selectedColor: ts.tintBg(ts.accentPrimary),
                      onSelected: (_) => setState(() => _filtroGrupoLotes = 'TODOS'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Venta Libre (Grupo VI)'),
                      selected: _filtroGrupoLotes == 'GRUPO_VI',
                      selectedColor: ts.tintBg(ts.accentPrimary),
                      onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_VI'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Antibióticos (Grupo IV)'),
                      selected: _filtroGrupoLotes == 'GRUPO_IV',
                      selectedColor: ts.tintBg(ts.neonAmber),
                      onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_IV'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Controlados (Grupo I-III)'),
                      selected: _filtroGrupoLotes == 'CONTROLADOS',
                      selectedColor: ts.tintBg(ts.neonRed),
                      onSelected: (_) => setState(() => _filtroGrupoLotes = 'CONTROLADOS'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Crónicos (Grupo V)'),
                      selected: _filtroGrupoLotes == 'GRUPO_V',
                      selectedColor: ts.tintBg(ts.neonPurple),
                      onSelected: (_) => setState(() => _filtroGrupoLotes = 'GRUPO_V'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Solo con Stock'),
                      selected: _soloConStockLotes,
                      selectedColor: ts.tintBg(ts.neonGreen),
                      onSelected: (val) => setState(() => _soloConStockLotes = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Listado de Medicamentos con sus Lotes
        Expanded(
          child: productosVisibles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 54, color: ts.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron medicamentos ni lotes para "${_busquedaLotesController.text.trim()}"',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Prueba buscando por nombre comercial, sustancia activa o número de lote.',
                        style: TextStyle(color: ts.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed: () {
                          _busquedaLotesController.clear();
                          setState(() {
                            _filtroGrupoLotes = 'TODOS';
                            _soloConStockLotes = false;
                          });
                        },
                        child: const Text('Limpiar Filtros y Ver Todos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: productosVisibles.length,
                  itemBuilder: (context, index) {
                    final p = productosVisibles[index];
                    final int stockTotal = p['stock_total'] ?? 0;
                    final bool requiereReceta = p['requiere_receta'] ?? false;
                    final String familiaTerap = (p['familia_terapeutica'] ?? '').toString().trim();
                    final String indicacionTerap = (p['indicacion_terapeutica'] ?? '').toString().trim();
                    final List<dynamic> lotes = p['lotes'] ?? [];
                    final Color roleColor = requiereReceta ? ts.neonAmber : ts.accentPrimary;
                    final Color stockColor = stockTotal <= 0
                        ? ts.neonRed
                        : (stockTotal > 10 ? ts.neonGreen : ts.neonAmber);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedHoverScaleCard(
                        hoverScale: 1.008,
                        child: PremiumSurfaceCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: ts.tintBg(roleColor),
                                  child: Icon(
                                    requiereReceta ? Icons.receipt_long : Icons.medication_liquid,
                                    color: roleColor,
                                  ),
                                ),
                                title: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      p['nombre_comercial'] ?? '',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: ts.textPrimary),
                                    ),
                                    if (familiaTerap.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ts.tintBg(ts.neonPurple),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: ts.neonPurple.withValues(alpha: 0.35)),
                                        ),
                                        child: Text(
                                          familiaTerap,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: ts.neonPurple,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ts.tintBg(roleColor),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: roleColor.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(
                                        p['grupo_farmacopea'] ?? 'GRUPO_VI',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p["sustancia_activa"]}  •  ${p["presentacion"]}\nPrecio: \$${p["precio_venta"]} MXN  •  ${lotes.length} ${lotes.length == 1 ? "lote registrado" : "lotes registrados"}',
                                      style: TextStyle(color: ts.textSecondary),
                                    ),
                                    if (indicacionTerap.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'IA / Indicación: $indicacionTerap',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: ts.neonBlue, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: ts.tintBg(stockColor),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: stockColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'Stock: $stockTotal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: stockColor,
                                    ),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            const Text(
                                              'Lotes en existencia (Prioridad FEFO):',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            if (!usuarioTienePermisoInventario())
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.neonAmber),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: ts.neonAmber.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  'Solo Administrador puede ajustar piezas o dar de baja',
                                                  style: TextStyle(fontSize: 10, color: ts.neonAmber, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (lotes.isEmpty)
                                          Text('Sin lotes activos registrados.', style: TextStyle(color: ts.textSecondary))
                                        else
                                          ...lotes.map((lote) {
                                            final bool loteActivo = lote['activo'] ?? true;
                                            final int loteStock = lote['stock_actual'] as int? ?? 0;
                                            final Color loteStockColor = !loteActivo
                                                ? ts.neonRed
                                                : (loteStock > 10 ? ts.neonGreen : (loteStock > 0 ? ts.neonAmber : ts.neonRed));
                                            return Container(
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: loteActivo ? ts.surfaceBg : ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: loteActivo ? ts.borderColor : ts.neonRed.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: LayoutBuilder(
                                                builder: (context, lConstraints) {
                                                  final bool isNarrow = lConstraints.maxWidth < 500;
                                                  final infoContent = Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            'Lote: ${lote["numero_lote"]}',
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                          ),
                                                          if (!loteActivo)
                                                            Container(
                                                              margin: const EdgeInsets.only(left: 6),
                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: ts.tintBg(ts.neonRed),
                                                                borderRadius: BorderRadius.circular(20),
                                                                border: Border.all(color: ts.neonRed.withValues(alpha: 0.4)),
                                                              ),
                                                              child: Text(
                                                                'DADO DE BAJA',
                                                                style: TextStyle(fontSize: 9, color: ts.neonRed, fontWeight: FontWeight.bold),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Caducidad: ${lote["fecha_caducidad"]} • Costo: \$${lote["costo_unitario"]}',
                                                        style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                                      ),
                                                      if (lote["laboratorio_fabricante"] != null ||
                                                          lote["forma_farmaceutica"] != null ||
                                                          lote["dosificacion"] != null ||
                                                          lote["fecha_ingreso"] != null)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4.0),
                                                          child: Wrap(
                                                            spacing: 6,
                                                            runSpacing: 4,
                                                            children: [
                                                              if (lote["laboratorio_fabricante"] != null)
                                                                ChipMetadatoLote(icon: Icons.factory, texto: lote["laboratorio_fabricante"], color: ts.neonBlue),
                                                              if (lote["forma_farmaceutica"] != null)
                                                                ChipMetadatoLote(icon: Icons.medication, texto: lote["forma_farmaceutica"], color: ts.neonPurple),
                                                              if (lote["dosificacion"] != null)
                                                                ChipMetadatoLote(icon: Icons.scale, texto: lote["dosificacion"], color: ts.accentPrimary),
                                                              if (lote["fecha_ingreso"] != null)
                                                                ChipMetadatoLote(icon: Icons.input, texto: 'Ingreso: ${lote["fecha_ingreso"]}', color: ts.neonAmber),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  );

                                                  final actionsContent = Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: ts.tintBg(loteStockColor),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(color: loteStockColor.withValues(alpha: 0.35)),
                                                        ),
                                                        child: Text(
                                                          '$loteStock pzas',
                                                          style: TextStyle(
                                                            color: loteStockColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        icon: Icon(Icons.tune, size: 20, color: ts.accentPrimary),
                                                        tooltip: 'Ajustar piezas de lote',
                                                        onPressed: () => mostrarDialogoAjustarPiezasLote(
                                                          context,
                                                          producto: p,
                                                          lote: lote,
                                                          onSuccess: widget.onReload,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete_outline, size: 20, color: ts.neonRed),
                                                        tooltip: 'Dar de baja lote',
                                                        onPressed: loteActivo
                                                            ? () => mostrarDialogoDarDeBajaLote(
                                                                  context,
                                                                  producto: p,
                                                                  lote: lote,
                                                                  onSuccess: widget.onReload,
                                                                )
                                                            : null,
                                                      ),
                                                    ],
                                                  );

                                                  if (isNarrow) {
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                                      children: [
                                                        infoContent,
                                                        const SizedBox(height: 6),
                                                        Align(
                                                          alignment: Alignment.centerRight,
                                                          child: actionsContent,
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return Row(
                                                      children: [
                                                        Expanded(child: infoContent),
                                                        const SizedBox(width: 12),
                                                        actionsContent,
                                                      ],
                                                    );
                                                  }
                                                },
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
