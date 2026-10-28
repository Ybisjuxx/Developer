import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

import 'services/theme_service.dart';

void main() {
  runApp(const FarmaciaApp());
}

class FarmaciaApp extends StatelessWidget {
  const FarmaciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'FarmaControl - Sistema de Farmacia',
          debugShowCheckedModeBanner: false,
          theme: themeService.obtenerTema(),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(themeService.factorEscala),
              ),
              child: child ?? const SizedBox(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
