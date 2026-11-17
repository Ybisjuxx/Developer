import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'clientes/cliente_detalle_dialog.dart';
import 'clientes/cliente_form_dialog.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<dynamic> _clientes = [];
  List<dynamic> _enfermedadesDisponibles = [];
  List<dynamic> _productosInventario = [];
  String _filtroResurtimiento = 'TODOS';
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientesFuture = ApiService.getClientes(
        buscar: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      final enfFuture = ApiService.getEnfermedades();
      final productosFuture = ApiService.getProductos();

      final results = await Future.wait([clientesFuture, enfFuture, productosFuture]);
      if (mounted) {
        setState(() {
          _clientes = results[0];
          _enfermedadesDisponibles = results[1];
          _productosInventario = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _clientesFiltrados {
    return _clientes.where((c) {
      final bool esCronico = c['tiene_padecimientos_cronicos'] == true;
      final int? dias = c['dias_para_resurtimiento'] as int?;
      final bool alerta = c['alerta_resurtimiento_activa'] == true;

      switch (_filtroResurtimiento) {
        case 'ALERTAS':
          return alerta;
        case 'VENCIDOS':
          return esCronico && dias != null && dias < 0;
        case 'AL_DIA':
          return esCronico && dias != null && dias > 21;
        case 'CRONICOS':
          return esCronico;
        case 'TODOS':
        default:
          return true;
      }
    }).toList();
  }

  int get _countAlertas => _clientes.where((c) => c['alerta_resurtimiento_activa'] == true).length;
  int get _countVencidos => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true && (c['dias_para_resurtimiento'] ?? 0) < 0).length;
  int get _countAlDia => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true && (c['dias_para_resurtimiento'] ?? 0) > 21).length;
  int get _countCronicos => _clientes.where((c) => c['tiene_padecimientos_cronicos'] == true).length;

  void _abrirFormularioCliente({Map<String, dynamic>? clienteExistente}) {
    showClienteFormDialog(
      context: context,
      clienteExistente: clienteExistente,
      enfermedadesDisponibles: _enfermedadesDisponibles,
      productosInventario: _productosInventario,
      onSaved: _cargarDatos,
    );
  }

  void _verDetallesCliente(Map<String, dynamic> c) {
    showClienteDetalleDialog(
      context: context,
      cliente: c,
      onEdit: () => _abrirFormularioCliente(clienteExistente: c),
    );
  }

  Widget _buildClienteKpiCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    required String filtroKey,
    required ThemeService ts,
    double? width,
  }) {
    final bool isSelected = _filtroResurtimiento == filtroKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filtroResurtimiento = isSelected && filtroKey != 'TODOS' ? 'TODOS' : filtroKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width ?? 190,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.24) : ts.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : ts.borderColor,
            width: 1.2,
          ),
          boxShadow: ts.cardGlowShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color : ts.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: ts.tintBg(color, lightAlpha: 0.14, darkAlpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : ts.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteFilterChip({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    required String filtroKey,
    required ThemeService ts,
  }) {
    final bool isSelected = _filtroResurtimiento == filtroKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filtroResurtimiento = isSelected && filtroKey != 'TODOS' ? 'TODOS' : filtroKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ts.tintBg(color, lightAlpha: 0.16, darkAlpha: 0.28) : ts.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : ts.borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : ts.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ts.tintBg(color, lightAlpha: 0.16, darkAlpha: 0.26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final bool isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: ts.scaffoldBg,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 20.0,
          vertical: isMobile ? 10.0 : 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de módulo HeroUI / Fragments UI
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 18,
                vertical: isMobile ? 10 : 14,
              ),
              decoration: BoxDecoration(
                gradient: ts.heroBannerGradient,
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: isMobile
                  ? Row(
                      children: [
                        Icon(
                          Icons.people_alt,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Padrón de Clientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _abrirFormularioCliente(),
                          icon: Icon(
                            Icons.person_add,
                            size: 16,
                            color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                          ),
                          label: Text(
                            'Nuevo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                            foregroundColor: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ts.esTemaNeon
                              ? ts.accentPrimary.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ts.esTemaNeon
                                ? ts.accentPrimary.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          Icons.people_alt,
                          color: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Padrón de Clientes y Expediente Clínico',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ts.esTemaNeon ? ts.textPrimary : Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Historial clínico CIE-11, tratamientos crónicos, descuentos de lealtad y alertas de resurtimiento.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ts.esTemaNeon ? ts.textSecondary : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _abrirFormularioCliente(),
                    icon: Icon(
                      Icons.person_add,
                      size: 18,
                      color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                    ),
                    label: Text(
                      'Registrar Nuevo Cliente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ts.esTemaNeon ? ts.accentPrimary : Colors.white,
                      foregroundColor: ts.esTemaNeon ? Colors.black : ts.colorActual.accentColor,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 14),

            // Tarjetas KPI Bento (escritorio) o Chips compactos horizontales (móvil)
            if (isMobile)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildClienteFilterChip(
                      titulo: 'Todos',
                      valor: '${_clientes.length}',
                      icono: Icons.people_outline,
                      color: ts.accentPrimary,
                      filtroKey: 'TODOS',
                      ts: ts,
                    ),
                    const SizedBox(width: 8),
                    _buildClienteFilterChip(
                      titulo: 'Resurtir',
                      valor: '$_countAlertas',
                      icono: Icons.alarm_on,
                      color: ts.neonAmber,
                      filtroKey: 'ALERTAS',
                      ts: ts,
                    ),
                    const SizedBox(width: 8),
                    _buildClienteFilterChip(
                      titulo: 'Vencido',
                      valor: '$_countVencidos',
                      icono: Icons.warning_amber_rounded,
                      color: ts.neonRed,
                      filtroKey: 'VENCIDOS',
                      ts: ts,
                    ),
                    const SizedBox(width: 8),
                    _buildClienteFilterChip(
                      titulo: 'Al Día',
                      valor: '$_countAlDia',
                      icono: Icons.check_circle_outline,
                      color: ts.neonGreen,
                      filtroKey: 'AL_DIA',
                      ts: ts,
                    ),
                    const SizedBox(width: 8),
                    _buildClienteFilterChip(
                      titulo: 'Crónicos',
                      valor: '$_countCronicos',
                      icono: Icons.medication_outlined,
                      color: ts.neonBlue,
                      filtroKey: 'CRONICOS',
                      ts: ts,
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
              builder: (context, kConstraints) {
                final double w = kConstraints.maxWidth;
                final double cardWidth = w < 480 ? (w - 12) / 2 : (w < 860 ? (w - 24) / 3 : 190);

                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildClienteKpiCard(
                      titulo: 'Todos los Clientes',
                      valor: '${_clientes.length}',
                      icono: Icons.people_outline,
                      color: ts.accentPrimary,
                      filtroKey: 'TODOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '⚠️ Próx. a Resurtir',
                      valor: '$_countAlertas',
                      icono: Icons.alarm_on,
                      color: ts.neonAmber,
                      filtroKey: 'ALERTAS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '🚨 Resurtido Vencido',
                      valor: '$_countVencidos',
                      icono: Icons.warning_amber_rounded,
                      color: ts.neonRed,
                      filtroKey: 'VENCIDOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '🟢 Tratamiento al Día',
                      valor: '$_countAlDia',
                      icono: Icons.check_circle_outline,
                      color: ts.neonGreen,
                      filtroKey: 'AL_DIA',
                      ts: ts,
                      width: cardWidth,
                    ),
                    _buildClienteKpiCard(
                      titulo: '💊 Pacientes Crónicos',
                      valor: '$_countCronicos',
                      icono: Icons.medication_outlined,
                      color: ts.neonBlue,
                      filtroKey: 'CRONICOS',
                      ts: ts,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isMobile ? 8 : 14),

            // Barra de Búsqueda
            Container(
              decoration: BoxDecoration(
                color: ts.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ts.borderColor, width: 1.2),
                boxShadow: ts.cardGlowShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.search, color: ts.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _cargarDatos(),
                        style: TextStyle(color: ts.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, apellido, teléfono o correo electrónico...',
                          hintStyle: TextStyle(color: ts.textSecondary.withValues(alpha: 0.7)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 20, color: ts.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _cargarDatos();
                        },
                      ),
                    FilledButton(
                      onPressed: _cargarDatos,
                      style: FilledButton.styleFrom(
                        backgroundColor: ts.accentPrimary,
                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: ts.neonRed, size: 40),
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyle(color: ts.neonRed)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ts.accentPrimary,
                                  foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                ),
                                onPressed: _cargarDatos,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _clientesFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 48, color: ts.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _clientes.isNotEmpty
                                        ? 'No se encontraron clientes con el filtro "$_filtroResurtimiento".'
                                        : 'No se encontraron clientes registrados con ese criterio.',
                                    style: TextStyle(fontSize: 15, color: ts.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_clientes.isNotEmpty && _filtroResurtimiento != 'TODOS')
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ts.accentPrimary,
                                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                      ),
                                      onPressed: () => setState(() => _filtroResurtimiento = 'TODOS'),
                                      child: const Text('Ver Todos los Clientes'),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ts.accentPrimary,
                                        foregroundColor: ts.esTemaNeon ? Colors.black : Colors.white,
                                      ),
                                      onPressed: () => _abrirFormularioCliente(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Registrar Primer Cliente'),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _clientesFiltrados.length,
                              itemBuilder: (context, index) {
                                final c = _clientesFiltrados[index];
                                final List enfermedades = c['enfermedades'] ?? [];
                                final double descuento = (c['descuento_porcentaje'] ?? 5.0).toDouble();
                                final bool esCronico = c['tiene_padecimientos_cronicos'] == true;
                                final int? dias = c['dias_para_resurtimiento'] as int?;
                                final bool alerta = c['alerta_resurtimiento_activa'] == true;
                                final bool vencido = esCronico && dias != null && dias < 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: ts.cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: ts.borderColor, width: 1.2),
                                    boxShadow: ts.cardGlowShadow,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: ts.tintBg(ts.accentPrimary, lightAlpha: 0.15, darkAlpha: 0.25),
                                      child: Text(
                                        '${c['nombre'][0]}${c['apellido'][0]}'.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ts.accentPrimary,
                                        ),
                                      ),
                                    ),
                                    title: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${c['nombre']} ${c['apellido']}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ts.textPrimary),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ts.tintBg(ts.neonGreen),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: ts.neonGreen.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            '$descuento% Desc. Lealtad',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: ts.neonGreen,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (esCronico) ...[
                                          if (vencido)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonRed),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonRed.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning, size: 12, color: ts.neonRed),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '🚨 Vencido hace ${dias.abs()}d',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonRed,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (alerta)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonAmber),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonAmber.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.alarm_on, size: 12, color: ts.neonAmber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '⚠️ Resurtir en ${dias ?? 0}d (~${((dias ?? 0) + 6) ~/ 7} sem)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonAmber,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ts.tintBg(ts.neonGreen),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: ts.neonGreen.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_outline, size: 12, color: ts.neonGreen),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '🟢 Al día (${dias ?? 0}d)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: ts.neonGreen,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        // Sub-Agente 4: Wrap responsivo para evitar overflow en tamaños grandes de fuente
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (c['telefono'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.phone, size: 13, color: ts.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(c['telefono'], style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                                                ],
                                              ),
                                            if (c['correo_electronico'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.email, size: 13, color: ts.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(c['correo_electronico'], style: TextStyle(fontSize: 12, color: ts.textSecondary)),
                                                ],
                                              ),
                                            if (c['sexo'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.neonBlue),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.neonBlue.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  c['sexo'] == 'MASCULINO' ? '♂ Masc' : (c['sexo'] == 'FEMENINO' ? '♀ Fem' : '${c['sexo']}'),
                                                  style: TextStyle(fontSize: 10, color: ts.neonBlue, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (c['fecha_nacimiento'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.neonPurple),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.neonPurple.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  '🎂 ${c["fecha_nacimiento"]}',
                                                  style: TextStyle(fontSize: 10, color: ts.neonPurple, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (esCronico && c['medicamento_cronico_principal'] != null) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.tintBg(ts.accentPrimary),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: ts.accentPrimary.withValues(alpha: 0.35)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.medication, size: 12, color: ts.accentPrimary),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'Rx: ${c["medicamento_cronico_principal"]}',
                                                        style: TextStyle(fontSize: 11, color: ts.accentPrimary, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (c['fecha_proximo_resurtimiento'] != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ts.surfaceBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: ts.borderColor),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.event, size: 12, color: ts.textSecondary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Próx. Resurtido: ${c["fecha_proximo_resurtimiento"]}',
                                                        style: TextStyle(fontSize: 11, color: ts.textSecondary, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        if (enfermedades.isNotEmpty)
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: enfermedades.map((enf) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ts.surfaceAltBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: ts.borderColor),
                                                ),
                                                child: Text(
                                                  '${enf['codigo_cie']}: ${enf['descripcion']}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: ts.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          )
                                        else
                                          Text(
                                            'Sin historial de enfermedades crónicas.',
                                            style: TextStyle(fontSize: 11, color: ts.textSecondary),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.visibility_outlined, color: ts.accentPrimary),
                                          tooltip: 'Ver Expediente Clínico',
                                          onPressed: () => _verDetallesCliente(c),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: ts.textSecondary),
                                          tooltip: 'Editar Cliente',
                                          onPressed: () => _abrirFormularioCliente(clienteExistente: c),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _verDetallesCliente(c),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
