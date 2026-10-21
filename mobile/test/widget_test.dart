import 'package:equilibra/data/models/resultado.dart';
import 'package:equilibra/screens/resultado_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Resultado _resultado(String nivel, {String? apoio}) => Resultado(
      avaliacaoId: 1,
      nivelRisco: nivel,
      probabilidades: const Probabilidades(baixo: 0.1, medio: 0.3, alto: 0.6),
      orientacoes: const ['Faça pausas curtas'],
      apoio: apoio,
      aviso: 'Não é diagnóstico',
      criadoEm: DateTime(2026, 10, 19),
    );

void main() {
  testWidgets('Resultado de risco alto mostra o nível e o apoio', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ResultadoTela(resultado: _resultado('alto', apoio: 'CVV: ligue 188')),
    ));

    expect(find.text('Risco alto'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Precisa conversar?'), findsOneWidget);
  });

  testWidgets('Resultado de risco baixo não mostra o cartão de apoio', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ResultadoTela(resultado: _resultado('baixo'))));

    expect(find.text('Risco baixo'), findsOneWidget);
    expect(find.text('Precisa conversar?'), findsNothing);
  });

  testWidgets('Cartão do nível de risco tem cor opaca no tema claro e no escuro', (tester) async {
    for (final brilho in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brilho),
        home: ResultadoTela(resultado: _resultado('alto')),
      ));

      final cartao = tester.widget<Card>(find.byType(Card).first);
      expect(cartao.color!.a, 1.0, reason: 'tema $brilho');
    }
  });
}
