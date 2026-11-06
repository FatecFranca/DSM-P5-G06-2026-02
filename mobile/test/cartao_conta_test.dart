import 'package:equilibra/screens/inicio_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mostrar(
  WidgetTester tester, {
  String? emailDaConta,
  VoidCallback? aoContinuarSemConta,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CartaoConta(
          emailDaConta: emailDaConta,
          aoContinuarSemConta: aoContinuarSemConta ?? () {},
        ),
      ),
    ));

void main() {
  testWidgets('sem conta: convida para criar', (tester) async {
    await mostrar(tester);
    expect(find.text('Acompanhe sua evolução'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Criar conta'), findsOneWidget);
    expect(find.text('Continuar sem conta'), findsNothing);
  });

  testWidgets('sessão expirada: permite entrar de novo ou seguir sem conta', (tester) async {
    var seguiuSemConta = false;
    await mostrar(tester, emailDaConta: 'ana@exemplo.com', aoContinuarSemConta: () => seguiuSemConta = true);

    expect(find.text('Sua sessão expirou'), findsOneWidget);
    expect(find.textContaining('ana@exemplo.com'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Entrar'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Continuar sem conta'));
    expect(seguiuSemConta, isTrue);
  });
}
