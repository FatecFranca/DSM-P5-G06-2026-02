import 'package:flutter/material.dart';

class Tema {
  static const semente = Color(0xFF2E7D6B); // verde-azulado: calma, equilíbrio

  static ThemeData claro() => ThemeData(
        colorSchemeSeed: semente,
        brightness: Brightness.light,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  static ThemeData escuro() => ThemeData(
        colorSchemeSeed: semente,
        brightness: Brightness.dark,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  /// Cor de cada nível de risco (sempre acompanhada de texto, nunca sozinha).
  static Color corDoRisco(String nivel) => switch (nivel) {
        'baixo' => const Color(0xFF2E7D32),
        'medio' => const Color(0xFFEF8F00),
        _ => const Color(0xFFC62828),
      };

  static String rotuloDoRisco(String nivel) => switch (nivel) {
        'baixo' => 'Risco baixo',
        'medio' => 'Risco médio',
        _ => 'Risco alto',
      };
}
