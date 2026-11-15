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
  final bool esNeonOscuro;

  const OpcionColorTema({
    required this.nombre,
    required this.primaryColor,
    required this.accentColor,
    this.esNeonOscuro = false,
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
    OpcionColorTema(
      nombre: 'Negro con Colores Vivos',
      primaryColor: Colors.cyan,
      accentColor: Color(0xFF00F5D4),
      esNeonOscuro: true,
    ),
  ];

  EscalaFuente _escalaActual = EscalaFuente.normal;
  OpcionColorTema _colorActual = coloresDisponibles[0];
  bool _modoOscuro = false;

  EscalaFuente get escalaActual => _escalaActual;
  OpcionColorTema get colorActual => _colorActual;
  bool get modoOscuro => _modoOscuro;
  double get factorEscala => _escalaActual.factor;

  bool get esTemaNeon => _colorActual.esNeonOscuro;
  bool get esOscuro => _modoOscuro || esTemaNeon;

  // Paleta semántica global reactiva con identidad cromática real por paleta
  Color get accentPrimary => esTemaNeon ? const Color(0xFF00F5D4) : _colorActual.primaryColor;
  Color get accentSecondary => esTemaNeon ? const Color(0xFFBB86FC) : _colorActual.accentColor;
  Color get headerBg => esTemaNeon
      ? const Color(0xFF090B10)
      : (esOscuro
          ? Color.lerp(const Color(0xFF0B1120), _colorActual.primaryColor, 0.22)!
          : _colorActual.accentColor);
  Color get scaffoldBg => esTemaNeon
      ? const Color(0xFF06080C)
      : (esOscuro
          ? Color.lerp(const Color(0xFF0E1525), _colorActual.primaryColor, 0.14)!
          : Color.lerp(const Color(0xFFF4F7FB), _colorActual.primaryColor, 0.08)!);
  Color get cardBg => esTemaNeon
      ? const Color(0xFF101520)
      : (esOscuro
          ? Color.lerp(const Color(0xFF162033), _colorActual.primaryColor, 0.12)!
          : Color.lerp(Colors.white, _colorActual.primaryColor, 0.025)!);
  Color get surfaceBg => esTemaNeon
      ? const Color(0xFF161D2C)
      : (esOscuro
          ? Color.lerp(const Color(0xFF1E293B), _colorActual.primaryColor, 0.16)!
          : Color.lerp(const Color(0xFFF8FAFC), _colorActual.primaryColor, 0.10)!);
  Color get surfaceAltBg => esTemaNeon
      ? const Color(0xFF1D273B)
      : (esOscuro
          ? Color.lerp(const Color(0xFF283548), _colorActual.primaryColor, 0.20)!
          : Color.lerp(const Color(0xFFF1F5F9), _colorActual.primaryColor, 0.16)!);
  Color get borderColor => esTemaNeon
      ? const Color(0xFF00F5D4).withValues(alpha: 0.40)
      : (esOscuro
          ? Color.lerp(Colors.white24, _colorActual.primaryColor, 0.35)!
          : Color.lerp(const Color(0xFFE2E8F0), _colorActual.primaryColor, 0.32)!);
  Color get textPrimary => esOscuro ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary => esOscuro ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  // Gradientes y sombras estilo Arc UI + HeroUI + Fragments UI
  LinearGradient get shellGradient => esTemaNeon
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF05070B), Color(0xFF0C1220), Color(0xFF080D16)],
        )
      : esOscuro
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF090F1D), _colorActual.primaryColor, 0.22)!,
                Color.lerp(const Color(0xFF111A2E), _colorActual.accentColor, 0.25)!,
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFFEFF4FA), _colorActual.primaryColor, 0.16)!,
                Color.lerp(const Color(0xFFF7FAFC), _colorActual.accentColor, 0.10)!,
              ],
            );

  LinearGradient get heroBannerGradient => esTemaNeon
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00F5D4).withValues(alpha: 0.20),
            const Color(0xFFBB86FC).withValues(alpha: 0.16),
          ],
        )
      : esOscuro
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _colorActual.accentColor.withValues(alpha: 0.72),
                _colorActual.primaryColor.shade800.withValues(alpha: 0.60),
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _colorActual.accentColor,
                _colorActual.primaryColor.shade600,
              ],
            );

  LinearGradient get headerGradient => esTemaNeon
      ? const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF080B12), Color(0xFF101828)],
        )
      : LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _colorActual.accentColor,
            _colorActual.primaryColor.shade700,
          ],
        );

  List<BoxShadow> get cardGlowShadow => [
        BoxShadow(
          color: accentPrimary.withValues(alpha: esTemaNeon ? 0.18 : 0.10),
          blurRadius: esTemaNeon ? 18 : 14,
          offset: const Offset(0, 6),
        ),
      ];

  // Colores vivos de estado / semáforos
  Color get neonGreen => esTemaNeon ? const Color(0xFF00E676) : (esOscuro ? Colors.greenAccent : Colors.green.shade700);
  Color get neonAmber => esTemaNeon ? const Color(0xFFFFD600) : (esOscuro ? Colors.amberAccent : Colors.amber.shade800);
  Color get neonRed => esTemaNeon ? const Color(0xFFFF5252) : (esOscuro ? Colors.redAccent : Colors.red.shade700);
  Color get neonPurple => esTemaNeon ? const Color(0xFFBB86FC) : (esOscuro ? Colors.purpleAccent : Colors.purple.shade700);
  Color get neonBlue => esTemaNeon ? const Color(0xFF38BDF8) : (esOscuro ? Colors.lightBlueAccent : Colors.blue.shade700);

  Color tintBg(Color base, {double lightAlpha = 0.10, double darkAlpha = 0.18}) {
    return base.withValues(alpha: esOscuro ? darkAlpha : lightAlpha);
  }

  void cambiarEscala(EscalaFuente nuevaEscala) {
    if (_escalaActual != nuevaEscala) {
      _escalaActual = nuevaEscala;
      notifyListeners();
    }
  }

  void cambiarColor(OpcionColorTema nuevoColor) {
    if (_colorActual != nuevoColor || _modoOscuro != nuevoColor.esNeonOscuro) {
      _colorActual = nuevoColor;
      // Al elegir una paleta clara se desactiva el modo negro; al elegir Negro Neón se activa.
      _modoOscuro = nuevoColor.esNeonOscuro;
      notifyListeners();
    }
  }

  void alternarModoOscuro(bool valor) {
    if (_modoOscuro != valor) {
      _modoOscuro = valor;
      if (!valor && _colorActual.esNeonOscuro) {
        _colorActual = coloresDisponibles[0];
      }
      notifyListeners();
    }
  }

  ThemeData obtenerTema() {
    final primary = accentPrimary;
    final secondary = accentSecondary;
    final brightness = esOscuro ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: esTemaNeon ? Colors.black : Colors.white,
      secondary: secondary,
      onSecondary: esTemaNeon ? Colors.black : Colors.white,
      surface: cardBg,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceBg,
      outline: borderColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: cardBg,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: Colors.white,
        elevation: esTemaNeon ? 0 : 1,
        centerTitle: false,
        shape: esTemaNeon
            ? Border(bottom: BorderSide(color: primary.withValues(alpha: 0.45), width: 1))
            : null,
      ),
      cardTheme: CardThemeData(
        elevation: esTemaNeon ? 0 : 1,
        surfaceTintColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        color: cardBg,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: esTemaNeon ? Colors.black : Colors.white,
          elevation: esTemaNeon ? 0 : 2,
          shadowColor: primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: esTemaNeon ? Colors.black : Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        dividerColor: borderColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: esOscuro ? BorderSide(color: borderColor, width: 1) : BorderSide.none,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cardBg,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardBg,
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
        selectedLabelTextStyle: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 11),
        indicatorColor: primary.withValues(alpha: esOscuro ? 0.22 : 0.14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceBg,
        selectedColor: primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(color: textPrimary, fontSize: 12),
        side: BorderSide(color: borderColor),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(surfaceBg),
        dataRowColor: WidgetStatePropertyAll(cardBg),
        headingTextStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        dataTextStyle: TextStyle(color: textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBg,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.75)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}
