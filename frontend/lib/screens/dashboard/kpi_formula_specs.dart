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
