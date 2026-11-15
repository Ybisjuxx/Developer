import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../widgets/premium_ui.dart';

class RadialProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  RadialProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circular de fondo
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Arco de progreso con puntas redondeadas
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class KpiFormulaSpec {
  final String ecuacion;
  final String? simboloResultado;
  final String? numerador;
  final String? denominador;
  final String? sufijo;
  final String? expresion;
  final List<String> componentes;

  const KpiFormulaSpec({
    required this.ecuacion,
    this.simboloResultado,
    this.numerador,
    this.denominador,
    this.sufijo,
    this.expresion,
    required this.componentes,
  });
}

KpiFormulaSpec obtenerFormulaKpi(String codigo, String descripcion) {
  const Map<String, String> alias = {
    'VTA-01': 'MV-01',
    'VTA-02': 'MV-02',
    'VTA-03': 'MV-03',
    'VTA-04': 'MV-04',
    'VTA-05': 'MV-05',
    'VTA-06': 'MV-06',
    'VTA-07': 'MV-07',
    'INV-01': 'AI-01',
    'INV-02': 'AI-02',
    'INV-03': 'AI-03',
    'INV-04': 'AI-04',
    'INV-05': 'AI-05',
    'INV-06': 'AI-06',
    'CMP-01': 'CP-01',
    'CMP-02': 'CP-02',
    'CMP-03': 'CP-03',
  };
  final raw = codigo.toUpperCase().trim();
  final c = alias[raw] ?? raw;
  const Map<String, KpiFormulaSpec> specs = {
    'MV-01': KpiFormulaSpec(
      ecuacion: 'TP = VT / NT',
      simboloResultado: 'TP =',
      numerador: 'VT',
      denominador: 'NT',
      componentes: [
        'TP: Ticket promedio por venta (\$).',
        'VT: Venta total cobrada en el periodo.',
        'NT: Número de tickets emitidos.',
      ],
    ),
    'MV-02': KpiFormulaSpec(
      ecuacion: 'UPT = PV / NT',
      simboloResultado: 'UPT =',
      numerador: 'PV',
      denominador: 'NT',
      componentes: [
        'UPT: Unidades promedio por ticket.',
        'PV: Total de piezas vendidas.',
        'NT: Número de tickets emitidos.',
      ],
    ),
    'MV-03': KpiFormulaSpec(
      ecuacion: 'VC = (TC / NT) × 100%',
      simboloResultado: 'VC =',
      numerador: 'TC',
      denominador: 'NT',
      sufijo: '× 100%',
      componentes: [
        'VC: Tasa de venta cruzada (%).',
        'TC: Tickets con ≥ 2 productos distintos.',
        'NT: Total de tickets emitidos.',
      ],
    ),
    'MV-04': KpiFormulaSpec(
      ecuacion: 'VP = ∑ (P × D0)',
      expresion: 'VP = ∑ (P × D₀)',
      componentes: [
        'VP: Venta perdida estimada (\$).',
        'P: Precio unitario del producto.',
        'D₀: Demanda consultada con stock = 0.',
      ],
    ),
    'MV-05': KpiFormulaSpec(
      ecuacion: 'TA = ∑ (Tc − Ti) / NV',
      simboloResultado: 'TA =',
      numerador: '∑ (Tc − Ti)',
      denominador: 'NV',
      componentes: [
        'TA: Tiempo promedio de atención.',
        'Tc − Ti: Segundos desde escaneo inicial al cobro.',
        'NV: Número de ventas atendidas.',
      ],
    ),
    'MV-06': KpiFormulaSpec(
      ecuacion: 'VCT = ∑ (VN | Cajero, Turno)',
      expresion: 'VCT = ∑ VN(Cajero, Turno)',
      componentes: [
        'VCT: Venta neta por cajero y turno.',
        'VN: Importe neto cobrado tras descuentos.',
        'Cajero/Turno: Responsable y corte asignado.',
      ],
    ),
    'MV-07': KpiFormulaSpec(
      ecuacion: 'TD = (TDV / TO) × 100%',
      simboloResultado: 'TD =',
      numerador: 'TDV',
      denominador: 'TO',
      sufijo: '× 100%',
      componentes: [
        'TD: Tasa de devolución/cancelación (%).',
        'TDV: Tickets devueltos o anulados.',
        'TO: Total de operaciones del mes.',
      ],
    ),
    'AI-01': KpiFormulaSpec(
      ecuacion: 'RI = CV / IP',
      simboloResultado: 'RI =',
      numerador: 'CV',
      denominador: 'IP',
      componentes: [
        'RI: Rotación de inventario (veces).',
        'CV: Costo de ventas del periodo.',
        'IP: Inventario promedio valuado.',
      ],
    ),
    'AI-02': KpiFormulaSpec(
      ecuacion: 'Q = (PA0 / PA) × 100%',
      simboloResultado: 'Q =',
      numerador: 'PA₀',
      denominador: 'PA',
      sufijo: '× 100%',
      componentes: [
        'Q: Índice de quiebre de stock (%).',
        'PA₀: Productos activos con stock = 0.',
        'PA: Total de productos activos.',
      ],
    ),
    'AI-03': KpiFormulaSpec(
      ecuacion: 'LC = ∑ Lotes(Cad ≤ 90d)',
      expresion: 'LC = ∑ Lotes (Cad ≤ 30, 60, 90 d)',
      componentes: [
        'LC: Lotes próximos a caducar (FEFO).',
        'Cad: Días restantes a fecha de vencimiento.',
      ],
    ),
    'AI-04': KpiFormulaSpec(
      ecuacion: 'SI = (V180 / IT) × 100%',
      simboloResultado: 'SI =',
      numerador: 'V₁₈₀',
      denominador: 'IT',
      sufijo: '× 100%',
      componentes: [
        'SI: Stock inmovilizado (%).',
        'V₁₈₀: Valor de stock sin ventas > 180 días.',
        'IT: Inventario total valuado.',
      ],
    ),
    'AI-05': KpiFormulaSpec(
      ecuacion: 'EI = 100% − (|SF − ST| / ST) × 100%',
      simboloResultado: 'EI = 100% −',
      numerador: '|SF − ST|',
      denominador: 'ST',
      sufijo: '× 100%',
      componentes: [
        'EI: Exactitud de inventario (%).',
        'SF: Conteo físico real en anaquel.',
        'ST: Stock teórico en Kardex SQL.',
      ],
    ),
    'AI-06': KpiFormulaSpec(
      ecuacion: 'MO = ∑ (PM × CU)',
      expresion: 'MO = ∑ (PM × CU)',
      componentes: [
        'MO: Merma operativa valorizada (\$).',
        'PM: Piezas dañadas o dadas de baja.',
        'CU: Costo unitario de reposición.',
      ],
    ),
    'CP-01': KpiFormulaSpec(
      ecuacion: 'DI = SA / VD',
      simboloResultado: 'DI =',
      numerador: 'SA',
      denominador: 'VD',
      componentes: [
        'DI: Días de inventario disponible.',
        'SA: Stock actual total en piezas.',
        'VD: Promedio de venta diaria.',
      ],
    ),
    'CP-02': KpiFormulaSpec(
      ecuacion: 'FR = (PS / PO) × 100%',
      simboloResultado: 'FR =',
      numerador: 'PS',
      denominador: 'PO',
      sufijo: '× 100%',
      componentes: [
        'FR: Nivel de surtido Fill Rate (%).',
        'PS: Piezas surtidas por proveedor.',
        'PO: Piezas solicitadas en la orden.',
      ],
    ),
    'CP-03': KpiFormulaSpec(
      ecuacion: 'LT = ∑ (Fr − Fo) / NO',
      simboloResultado: 'LT =',
      numerador: '∑ (Fr − Fo)',
      denominador: 'NO',
      componentes: [
        'LT: Lead time promedio (días).',
        'Fr − Fo: Días entre orden y recepción.',
        'NO: Total de órdenes recibidas.',
      ],
    ),
    'CP-04': KpiFormulaSpec(
      ecuacion: 'CC = (Ccr / CT) × 100%',
      simboloResultado: 'CC =',
      numerador: 'Ccr',
      denominador: 'CT',
      sufijo: '× 100%',
      componentes: [
        'CC: Compras a crédito (%).',
        'Ccr: Compras pactadas a plazo (\$).',
        'CT: Total de compras del periodo (\$).',
      ],
    ),
    'CP-05': KpiFormulaSpec(
      ecuacion: 'AN = (A / CB) × 100%',
      simboloResultado: 'AN =',
      numerador: 'A',
      denominador: 'CB',
      sufijo: '× 100%',
      componentes: [
        'AN: Ahorro en compras (%).',
        'A: Descuentos y bonificaciones obtenidas.',
        'CB: Costo base de lista de catálogo.',
      ],
    ),
    'CMP-04': KpiFormulaSpec(
      ecuacion: 'VCp = ((Ca − Ch) / Ch) × 100%',
      simboloResultado: 'VCp =',
      numerador: 'Ca − Ch',
      denominador: 'Ch',
      sufijo: '× 100%',
      componentes: [
        'VCp: Variación de costos de compra (%).',
        'Ca: Costo unitario promedio actual.',
        'Ch: Costo unitario histórico de referencia.',
      ],
    ),
    'CMP-05': KpiFormulaSpec(
      ecuacion: 'CPP = (CP / CT) × 100%',
      simboloResultado: 'CPP =',
      numerador: 'CP',
      denominador: 'CT',
      sufijo: '× 100%',
      componentes: [
        'CPP: Concentración por proveedor principal (%).',
        'CP: Compras al distribuidor líder (\$).',
        'CT: Total de compras del periodo (\$).',
      ],
    ),
    'FIN-01': KpiFormulaSpec(
      ecuacion: 'MB = ((IN − CV) / IN) × 100%',
      simboloResultado: 'MB =',
      numerador: 'IN − CV',
      denominador: 'IN',
      sufijo: '× 100%',
      componentes: [
        'MB: Margen bruto (%).',
        'IN: Ingresos netos tras devoluciones.',
        'CV: Costo de ventas de lo despachado.',
      ],
    ),
    'FIN-02': KpiFormulaSpec(
      ecuacion: 'UN = IN − CV − GO',
      expresion: 'UN = IN − CV − GO',
      componentes: [
        'UN: Utilidad neta mensual (\$).',
        'IN: Ingresos netos del mes.',
        'CV: Costo de mercancía; GO: Gastos operativos.',
      ],
    ),
    'FIN-03': KpiFormulaSpec(
      ecuacion: 'PE = GF / MB',
      simboloResultado: 'PE =',
      numerador: 'GF',
      denominador: 'MB',
      componentes: [
        'PE: Punto de equilibrio mensual (\$).',
        'GF: Gastos fijos estimados del mes.',
        'MB: Margen de contribución bruto (%).',
      ],
    ),
    'FIN-04': KpiFormulaSpec(
      ecuacion: 'CN = (GN / VN) × 100%',
      simboloResultado: 'CN =',
      numerador: 'GN',
      denominador: 'VN',
      sufijo: '× 100%',
      componentes: [
        'CN: Costo de nómina sobre ventas (%).',
        'GN: Gasto total de nómina.',
        'VN: Ventas netas del periodo.',
      ],
    ),
    'FIN-05': KpiFormulaSpec(
      ecuacion: 'FC = FA + VE − EG',
      expresion: 'FC = FA + VE − EG',
      componentes: [
        'FC: Flujo de efectivo en caja (\$).',
        'FA: Fondo de apertura en turno.',
        'VE: Ventas en efectivo; EG: Egresos/retiros.',
      ],
    ),
    'FIN-06': KpiFormulaSpec(
      ecuacion: 'GMROI = MBA / IP',
      simboloResultado: 'GMROI =',
      numerador: 'MBA',
      denominador: 'IP',
      componentes: [
        'GMROI: Retorno de inversión en inventario.',
        'MBA: Margen bruto anualizado (\$).',
        'IP: Inventario promedio valuado (\$).',
      ],
    ),
    'CAL-01': KpiFormulaSpec(
      ecuacion: 'RC = (CR60 / CT) × 100%',
      simboloResultado: 'RC =',
      numerador: 'CR₆₀',
      denominador: 'CT',
      sufijo: '× 100%',
      componentes: [
        'RC: Tasa de retención de clientes (%).',
        'CR₆₀: Clientes que recompraron en 60 días.',
        'CT: Total de clientes frecuentes activos.',
      ],
    ),
    'CAL-02': KpiFormulaSpec(
      ecuacion: 'SR = (RS / RT) × 100%',
      simboloResultado: 'SR =',
      numerador: 'RS',
      denominador: 'RT',
      sufijo: '× 100%',
      componentes: [
        'SR: Surtido de recetas completas (%).',
        'RS: Recetas surtidas al 100%.',
        'RT: Total de recetas presentadas.',
      ],
    ),
    'CAL-03': KpiFormulaSpec(
      ecuacion: 'IQ = ∑ Incidencias',
      expresion: 'IQ = ∑ (Anomalías + Quejas)',
      componentes: [
        'IQ: Índice de incidencias/quejas.',
        'Anomalías: Banderas en auditoría de Kardex.',
        'Quejas: Incidencias formales de mostrador.',
      ],
    ),
    'CAL-04': KpiFormulaSpec(
      ecuacion: 'AC = (CD / TC) × 100%',
      simboloResultado: 'AC =',
      numerador: 'CD',
      denominador: 'TC',
      sufijo: '× 100%',
      componentes: [
        'AC: Adherencia a tratamientos crónicos (%).',
        'CD: Pacientes CIE-11 al día en resurtido.',
        'TC: Total de pacientes crónicos activos.',
      ],
    ),
    'COF-01': KpiFormulaSpec(
      ecuacion: 'CC = (CL / SF) × 100%',
      simboloResultado: 'CC =',
      numerador: 'CL',
      denominador: 'SF',
      sufijo: '× 100%',
      componentes: [
        'CC: Cuadratura de controlados (%).',
        'CL: Saldo en libro y recetas retenidas.',
        'SF: Existencia física Fracc. I–III.',
      ],
    ),
    'COF-02': KpiFormulaSpec(
      ecuacion: 'IA = (VR / AB) × 100%',
      simboloResultado: 'IA =',
      numerador: 'VR',
      denominador: 'AB',
      sufijo: '× 100%',
      componentes: [
        'IA: Cumplimiento antibióticos Fracc. IV (%).',
        'VR: Ventas con receta retenida válida.',
        'AB: Cajas de antibiótico vendidas.',
      ],
    ),
    'COF-03': KpiFormulaSpec(
      ecuacion: 'TR = (RC / RT) × 100%',
      simboloResultado: 'TR =',
      numerador: 'RC',
      denominador: 'RT',
      sufijo: '× 100%',
      componentes: [
        'TR: Recetas retenidas sin errores (%).',
        'RC: Recetas con cédula, firma y fecha.',
        'RT: Total de recetas archivadas.',
      ],
    ),
    'COF-04': KpiFormulaSpec(
      ecuacion: 'TH = (LR / LT) × 100%',
      simboloResultado: 'TH =',
      numerador: 'LR',
      denominador: 'LT',
      sufijo: '× 100%',
      componentes: [
        'TH: Cumplimiento temperatura/humedad (%).',
        'LR: Lecturas en rango (15–30°C / 2–8°C).',
        'LT: Total de lecturas registradas.',
      ],
    ),
    'COF-05': KpiFormulaSpec(
      ecuacion: 'TL = (ML / MT) × 100%',
      simboloResultado: 'TL =',
      numerador: 'ML',
      denominador: 'MT',
      sufijo: '× 100%',
      componentes: [
        'TL: Trazabilidad de lote y caducidad (%).',
        'ML: Movimientos Kardex con lote vinculado.',
        'MT: Total de movimientos del periodo.',
      ],
    ),
    'COF-06': KpiFormulaSpec(
      ecuacion: 'CQ = ∑ Piezas Caducadas',
      expresion: 'CQ = ∑ Lotes(Cad < Hoy)',
      componentes: [
        'CQ: Piezas segregadas a cuarentena SINGREM.',
        'Cad < Hoy: Lotes vencidos fuera de venta.',
      ],
    ),
    'COF-07': KpiFormulaSpec(
      ecuacion: 'DV = Fv − Hoy',
      expresion: 'DV = min(Fv − Hoy)',
      componentes: [
        'DV: Días vigentes de documentación legal.',
        'Fv: Fecha de vencimiento más próxima.',
      ],
    ),
  };

  return specs[c] ??
      KpiFormulaSpec(
        ecuacion: 'KPI = ∑ Datos(SQL) / Periodo',
        expresion: descripcion.isNotEmpty
            ? 'KPI = $descripcion'
            : 'KPI = Cálculo agregado en SQL',
        componentes: [
          'KPI: Valor calculado del indicador.',
          'Datos(SQL): Registros transaccionales del mes.',
        ],
      );
}

class FormulaMatematicaBox extends StatelessWidget {
  final KpiFormulaSpec spec;
  final Color areaColor;

  const FormulaMatematicaBox({
    super.key,
    required this.spec,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final Color boxBg = ts.esOscuro ? ts.surfaceAltBg : ts.surfaceBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: areaColor.withValues(alpha: 0.45)),
          ),
          child: (spec.numerador != null && spec.denominador != null)
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (spec.simboloResultado != null) ...[
                      Text(
                        spec.simboloResultado!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: areaColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            spec.numerador!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ts.textPrimary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            height: 1.8,
                            color: areaColor,
                          ),
                          Text(
                            spec.denominador!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ts.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (spec.sufijo != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        spec.sufijo!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: areaColor,
                        ),
                      ),
                    ],
                  ],
                )
              : Center(
                  child: Text(
                    spec.expresion ?? spec.ecuacion,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ts.textPrimary,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dónde:',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: areaColor,
          ),
        ),
        const SizedBox(height: 3),
        ...spec.componentes.map(
          (comp) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    comp,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: ts.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedRadialGaugeCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final Color areaColor;

  const AnimatedRadialGaugeCard({super.key, 
    required this.kpi,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final String codigo = kpi['codigo'] as String? ?? '';
    final String nombre = kpi['nombre'] as String? ?? '';
    final String meta = kpi['meta'] as String? ?? '';
    final String estado = (kpi['estado'] as String? ?? 'OPTIMO').toUpperCase().trim();
    final double pctMeta = ((kpi['porcentaje_meta'] as num?) ?? 0.0).toDouble().clamp(0.0, 100.0);
    final double valorNum = ((kpi['valor'] as num?) ?? pctMeta).toDouble();
    final String unidad = kpi['unidad'] as String? ?? '%';
    final String descripcion = kpi['descripcion'] as String? ?? '';
    final formulaSpec = obtenerFormulaKpi(codigo, descripcion);

    Color statusColor;
    if (estado == 'OPTIMO') {
      statusColor = ts.neonGreen;
    } else if (estado == 'CRITICO') {
      statusColor = ts.neonRed;
    } else {
      statusColor = ts.neonAmber;
    }

    final frontCard = Container(
      width: 215,
      height: 235,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ts.borderColor),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: areaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
              ),
              _buildSemanticStatusBadge(estado),
            ],
          ),
          SizedBox(
            width: 92,
            height: 92,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('radial_${codigo}_$pctMeta'),
              tween: Tween<double>(begin: 0.0, end: pctMeta / 100.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                return CustomPaint(
                  painter: RadialProgressPainter(
                    progress: progress,
                    trackColor: ts.borderColor.withValues(alpha: 0.5),
                    progressColor: statusColor,
                    strokeWidth: 8.0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unidad == '%' ? '${(progress * 100).toStringAsFixed(1)}%' : valorNum.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ts.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% meta',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: ts.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            children: [
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ts.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Meta: $meta',
                      style: TextStyle(
                        fontSize: 10,
                        color: ts.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.flip_rounded, size: 12, color: areaColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final backCard = Container(
      width: 230,
      height: 245,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: areaColor, width: 1.5),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$codigo • Fórmula',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: areaColor,
                ),
              ),
              Icon(Icons.flip_to_front_rounded, size: 14, color: areaColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ts.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: 12, color: areaColor.withValues(alpha: 0.25)),
          Expanded(
            child: SingleChildScrollView(
              child: FormulaMatematicaBox(
                spec: formulaSpec,
                areaColor: areaColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca para volver',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: areaColor,
            ),
          ),
        ],
      ),
    );

    return FlippableArcCard(front: frontCard, back: backCard);
  }
}

class BentoKpiCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final Color areaColor;

  const BentoKpiCard({super.key, 
    required this.kpi,
    required this.areaColor,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;
    final String codigo = kpi['codigo'] as String? ?? '';
    final String nombre = kpi['nombre'] as String? ?? '';
    final dynamic valor = kpi['valor'];
    final String unidad = kpi['unidad'] as String? ?? '';
    final String meta = kpi['meta'] as String? ?? '';
    final String estado = (kpi['estado'] as String? ?? 'OPTIMO').toUpperCase().trim();
    final double pctMeta = ((kpi['porcentaje_meta'] as num?) ?? 0.0).toDouble().clamp(0.0, 100.0);
    final String descripcion = kpi['descripcion'] as String? ?? '';

    Color statusColor;
    if (estado == 'OPTIMO') {
      statusColor = ts.neonGreen;
    } else if (estado == 'CRITICO') {
      statusColor = ts.neonRed;
    } else {
      statusColor = ts.neonAmber;
    }

    String valorFormateado = '$valor';
    if (valor is num) {
      if (unidad == 'MXN' || unidad.contains('MXN')) {
        valorFormateado = '\$${valor.toStringAsFixed(2)}';
      } else if (valor is double) {
        valorFormateado = valor.toStringAsFixed(1);
      }
    }

    final formulaSpec = obtenerFormulaKpi(codigo, descripcion);

    final frontCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ts.borderColor,
          width: 1.2,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fila superior: Código, Badge semántico e ícono de giro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: areaColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: areaColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: areaColor,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSemanticStatusBadge(estado),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Ver cómo se calcula',
                    child: Icon(Icons.flip_rounded, size: 15, color: areaColor),
                  ),
                ],
              ),
            ],
          ),

          // Título y Valor numérico
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ts.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    valorFormateado,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ts.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (unidad.isNotEmpty && !valorFormateado.contains(unidad)) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        unidad,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ts.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Meta y barra de progreso animada
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Meta: $meta',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ts.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pctMeta.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: ts.borderColor.withValues(alpha: 0.5),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('bar_${codigo}_$pctMeta'),
                    tween: Tween<double>(begin: 0.0, end: pctMeta / 100.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, factor, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: factor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Descripción explicativa
          Text(
            descripcion,
            style: TextStyle(
              fontSize: 10,
              color: ts.textSecondary.withValues(alpha: 0.85),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final backCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ts.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: areaColor,
          width: 1.5,
        ),
        boxShadow: ts.cardGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_rounded, size: 16, color: areaColor),
                  const SizedBox(width: 6),
                  Text(
                    '$codigo • ¿Cómo se calcula?',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: areaColor,
                    ),
                  ),
                ],
              ),
              Icon(Icons.flip_to_front_rounded, size: 15, color: areaColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ts.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: 14, color: areaColor.withValues(alpha: 0.28)),
          Expanded(
            child: SingleChildScrollView(
              child: FormulaMatematicaBox(
                spec: formulaSpec,
                areaColor: areaColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Actual: $valorFormateado • Meta: $meta',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Toca para volver',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: areaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return FlippableArcCard(front: frontCard, back: backCard);
  }
}

Widget _buildSemanticStatusBadge(String estadoRaw) {
  final ts = ThemeService.instance;
  final estado = estadoRaw.toUpperCase().trim();

  Color color;
  IconData icon;
  String label;

  switch (estado) {
    case 'OPTIMO':
      color = ts.neonGreen;
      icon = Icons.check_circle_outline_rounded;
      label = 'ÓPTIMO';
      break;
    case 'PREVENTIVO':
      color = ts.neonAmber;
      icon = Icons.warning_amber_rounded;
      label = 'PREVENTIVO';
      break;
    case 'CRITICO':
      color = ts.neonRed;
      icon = Icons.error_outline_rounded;
      label = 'CRÍTICO';
      break;
    default:
      color = ts.neonBlue;
      icon = Icons.info_outline_rounded;
      label = estado;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

Widget buildMiniBadgeEstado({
  required String label,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
