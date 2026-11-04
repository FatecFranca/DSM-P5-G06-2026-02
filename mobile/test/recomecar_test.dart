import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/screens/entrar_tela.dart';
import 'package:equilibra/screens/historico_tela.dart';
import 'package:equilibra/screens/questionario_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'apoio/falsos.dart';

/// Quando o servidor não reconhece o aparelho, o app limpa os dados locais e volta ao termo
/// (antes ele pedia "reabra o app e aceite o termo", mas nunca reabria o termo).
Future<ProviderContainer> abrir(WidgetTester tester, ApiFalsa api, Widget tela) async {
  tester.view.physicalSize = const Size(800, 3200); // tela inteira visível
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = await criarContainer(api, prefs: {'usuario_id': 'id-perdido', 'consentiu': true});
  addTearDown(container.dispose);
  final rotas = GoRouter(initialLocation: '/tela', routes: [
    GoRoute(path: '/tela', builder: (_, _) => tela),
    GoRoute(path: '/consentimento', builder: (_, _) => const Scaffold(body: Text('TERMO'))),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: rotas),
  ));
  await tester.pumpAndSettle();
  return container;
}

void verificarRecomeco(WidgetTester tester, ProviderContainer container) {
  expect(find.text('TERMO'), findsOneWidget);
  expect(find.textContaining('Aceite o termo de novo'), findsOneWidget);
  expect(container.read(armazenamentoProvider).consentiu, isFalse);
  expect(container.read(armazenamentoProvider).usuarioId, isNot('id-perdido'));
}

void main() {
  testWidgets('questionário: cadastro ausente leva de volta ao termo', (tester) async {
    final api = ApiFalsa()..erroDados = ErroCadastroAusente();
    final container = await abrir(tester, api, const QuestionarioTela());

    await tester.tap(find.text('Ver meu resultado'));
    await tester.pumpAndSettle();

    expect(api.chamadas, ['prever']);
    verificarRecomeco(tester, container);
  });

  testWidgets('histórico: cadastro ausente oferece aceitar o termo de novo', (tester) async {
    final api = ApiFalsa()..erroDados = ErroCadastroAusente();
    final container = await abrir(tester, api, const HistoricoTela());

    await tester.tap(find.text('Aceitar o termo de novo'));
    await tester.pumpAndSettle();

    verificarRecomeco(tester, container);
  });

  testWidgets('criar conta: cadastro ausente leva de volta ao termo', (tester) async {
    final api = ApiFalsa()..erro = ErroCadastroAusente();
    final container = await abrir(tester, api, const EntrarTela());

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), '12345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirme a senha'), '12345678');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pumpAndSettle();

    verificarRecomeco(tester, container);
  });

  testWidgets('outros erros continuam só como aviso, sem apagar nada', (tester) async {
    final api = ApiFalsa()..erroDados = ErroApi('Sem conexão com o servidor.');
    final container = await abrir(tester, api, const QuestionarioTela());

    await tester.tap(find.text('Ver meu resultado'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.text('TERMO'), findsNothing);
    expect(container.read(armazenamentoProvider).consentiu, isTrue);
  });
}
