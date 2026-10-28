import 'package:flutter/material.dart';

enum EscalaFuente {
  compacta(0.88, 'Compacta (88%)'),
  normal(1.0, 'Estándar (100%)'),
  grande(1.15, 'Grande (115%)'),
  accesible(1.30, 'Alta Legibilidad (130%)');

  final double factor;
  final String etiqueta;
  const EscalaFuente(this.factor, this.etiqueta);
}

class OpcionColorTema {
  final String nombre;
  final MaterialColor primaryColor;
  final Color accentColor;

  const OpcionColorTema({
    required this.nombre,
    required this.primaryColor,
    required this.accentColor,
  });
}

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._internal();

  factory ThemeService() {
    return instance;
  }

  ThemeService._internal();

  static const List<OpcionColorTema> coloresDisponibles = [
    OpcionColorTema(
      nombre: 'Teal Farmacéutico',
      primaryColor: Colors.teal,
      accentColor: Color(0xFF004D40),
    ),
    OpcionColorTema(
      nombre: 'Azul Clínico',
      primaryColor: Colors.blue,
      accentColor: Color(0xFF0D47A1),
    ),
    OpcionColorTema(
      nombre: 'Verde Médico',
      primaryColor: Colors.green,
      accentColor: Color(0xFF1B5E20),
    ),
    OpcionColorTema(
      nombre: 'Índigo Quirúrgico',
      primaryColor: Colors.indigo,
      accentColor: Color(0xFF1A237E),
    ),
    OpcionColorTema(
      nombre: 'Cian Sanitario',
      primaryColor: Colors.cyan,
      accentColor: Color(0xFF006064),
    ),
  ];

  EscalaFuente _escalaActual = EscalaFuente.normal;
  OpcionColorTema _colorActual = coloresDisponibles[0];
  bool _modoOscuro = false;

  EscalaFuente get escalaActual => _escalaActual;
  OpcionColorTema get colorActual => _colorActual;
  bool get modoOscuro => _modoOscuro;
  double get factorEscala => _escalaActual.factor;

  void cambiarEscala(EscalaFuente nuevaEscala) {
    if (_escalaActual != nuevaEscala) {
      _escalaActual = nuevaEscala;
      notifyListeners();
    }
  }

  void cambiarColor(OpcionColorTema nuevoColor) {
    if (_colorActual != nuevoColor) {
      _colorActual = nuevoColor;
      notifyListeners();
    }
  }

  void alternarModoOscuro(bool valor) {
    if (_modoOscuro != valor) {
      _modoOscuro = valor;
      notifyListeners();
    }
  }

  ThemeData obtenerTema() {
    final baseColor = _colorActual.primaryColor;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseColor,
      brightness: _modoOscuro ? Brightness.dark : Brightness.light,
      primary: baseColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: baseColor,
      scaffoldBackgroundColor: _modoOscuro ? const Color(0xFF121820) : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: _modoOscuro ? const Color(0xFF1E2632) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _modoOscuro ? const Color(0xFF283344) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: baseColor, width: 2),
        ),
      ),
    );
  }
}
