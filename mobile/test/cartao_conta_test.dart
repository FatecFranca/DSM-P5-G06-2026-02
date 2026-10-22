import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/screens/inicio_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mostrar(
  WidgetTester tester, {
  Sessao? sessao,
  String? emailDaConta,
  VoidCallback? aoContinuarSemConta,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CartaoConta(
          sessao: sessao,
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

  testWidgets('com sessão: mostra o e-mail conectado', (tester) async {
    await mostrar(
      tester,
      sessao: Sessao(token: 't', usuarioId: 'u', email: 'ana@exemplo.com', expiraEm: DateTime(2100)),
      emailDaConta: 'ana@exemplo.com',
    );
    expect(find.text('Conectado como ana@exemplo.com'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
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
