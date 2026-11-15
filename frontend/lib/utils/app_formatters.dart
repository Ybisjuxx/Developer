import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utilidades centralizadas de formato y semántica visual para FarmaControl.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _monedaMx = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String fmtMoneda(num? valor) => _monedaMx.format((valor ?? 0).toDouble());

  static String fmtFechaHora(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  static Color colorPorRol(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMINISTRADOR':
        return Colors.deepPurple.shade600;
      case 'RESPONSABLE_SANITARIO':
        return Colors.teal.shade700;
      case 'CAJERO':
      default:
        return Colors.blue.shade700;
    }
  }

  static Color colorEstadoVenta(String estado) {
    switch (estado.toUpperCase()) {
      case 'COMPLETADA':
        return Colors.green.shade700;
      case 'CANCELADA':
        return Colors.red.shade700;
      case 'DEVUELTA':
      case 'DEVOLUCION_PARCIAL':
        return Colors.orange.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  static Color colorGrupoFarmacopea(String grupo) {
    switch (grupo.toUpperCase()) {
      case 'GRUPO_I':
      case 'GRUPO_II':
      case 'GRUPO_III':
        return Colors.red.shade700;
      case 'GRUPO_IV':
        return Colors.amber.shade800;
      case 'GRUPO_V':
      case 'GRUPO_VI':
        return Colors.teal.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }
}
