import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/screens/entrar_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'apoio/falsos.dart';

/// Monta a tela dentro de um app com as rotas '/' e '/entrar'.
Future<ProviderContainer> abrir(WidgetTester tester, ApiFalsa api, {ModoConta modo = ModoConta.criar}) async {
  tester.view.physicalSize = const Size(800, 2400); // formulário inteiro visível
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = await criarContainer(api, prefs: {'usuario_id': 'anon-1', 'consentiu': true});
  addTearDown(container.dispose);
  final rotas = GoRouter(initialLocation: '/entrar', routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('TELA INICIAL'))),
    GoRoute(path: '/entrar', builder: (_, _) => EntrarTela(modoInicial: modo)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: rotas),
  ));
  return container;
}

Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);
Finder botao(String texto) => find.widgetWithText(FilledButton, texto);

void main() {
  testWidgets('criar conta valida os campos antes de chamar a API', (tester) async {
    final api = ApiFalsa();
    await abrir(tester, api);

    await tester.tap(botao('Criar conta'));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Crie uma senha.'), findsOneWidget);

    await tester.enterText(campo('E-mail'), 'ana@exemplo.com');
    await tester.enterText(campo('Senha'), '1234');
    await tester.enterText(campo('Confirme a senha'), '9999');
    await tester.tap(botao('Criar conta'));
    await tester.pump();
    expect(find.textContaining('pelo menos 8'), findsOneWidget);
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(api.chamadas, isEmpty);
  });

  testWidgets('criar conta exige o aceite do termo', (tester) async {
    final api = ApiFalsa();
    await abrir(tester, api);

    await tester.enterText(campo('E-mail'), 'ana@exemplo.com');
    await tester.enterText(campo('Senha'), '12345678');
    await tester.enterText(campo('Confirme a senha'), '12345678');
    await tester.tap(botao('Criar conta'));
    await tester.pump();

    expect(find.text('Aceite o termo para criar a conta.'), findsOneWidget);
    expect(api.chamadas, isEmpty);
  });

  testWidgets('cadastro válido cria a conta e volta ao início', (tester) async {
    final api = ApiFalsa();
    final container = await abrir(tester, api);

    await tester.enterText(campo('E-mail'), ' Ana@Exemplo.com ');
    await tester.enterText(campo('Senha'), '12345678');
    await tester.enterText(campo('Confirme a senha'), '12345678');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(botao('Criar conta'));
    await tester.pumpAndSettle();

    expect(api.chamadas, ['cadastrar']);
    expect(container.read(sessaoProvider)?.email, 'ana@exemplo.com'); // sem espaços, minúsculo
    expect(find.text('TELA INICIAL'), findsOneWidget);
  });

  testWidgets('aba Entrar não pede confirmação nem termo e faz login', (tester) async {
    final api = ApiFalsa();
    await abrir(tester, api, modo: ModoConta.entrar);

    expect(campo('Confirme a senha'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.enterText(campo('E-mail'), 'ana@exemplo.com');
    await tester.enterText(campo('Senha'), 'qualquer');
    await tester.tap(botao('Entrar'));
    await tester.pumpAndSettle();

    expect(api.chamadas, ['entrar']);
    expect(api.ultimoIdAnonimo, 'anon-1');
    expect(find.text('TELA INICIAL'), findsOneWidget);
  });

  testWidgets('erro da API aparece para o usuário e a tela continua aberta', (tester) async {
    final api = ApiFalsa()..erro = ErroApi('E-mail ou senha incorretos.');
    await abrir(tester, api, modo: ModoConta.entrar);

    await tester.enterText(campo('E-mail'), 'ana@exemplo.com');
    await tester.enterText(campo('Senha'), 'errada');
    await tester.tap(botao('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.byType(EntrarTela), findsOneWidget);
  });

  testWidgets('trocar de aba mostra os campos de cadastro', (tester) async {
    await abrir(tester, ApiFalsa(), modo: ModoConta.entrar);
    await tester.tap(find.text('Criar conta').first);
    await tester.pump();
    expect(campo('Confirme a senha'), findsOneWidget);
  });
}
