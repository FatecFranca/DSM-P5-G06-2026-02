// Regras de navegação com o roteador REAL do app: bloqueio do termo (LGPD) e acesso à Home.
import 'package:equilibra/core/rotas.dart';
import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/screens/consentimento_tela.dart';
import 'package:equilibra/screens/entrar_tela.dart';
import 'package:equilibra/screens/historico_tela.dart';
import 'package:equilibra/screens/home_tela.dart';
import 'package:equilibra/screens/inicio_tela.dart';
import 'package:equilibra/screens/questionario_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio/falsos.dart';

final _sessao = Sessao(token: 't', usuarioId: 'conta-1', email: 'ana@exemplo.com', expiraEm: DateTime(2099));
const _aceitou = {'usuario_id': 'anon-1', 'consentiu': true};

Future<GoRouter> abrirApp(WidgetTester tester, {Map<String, Object> prefs = const {}, Sessao? sessao}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiFalsa();
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    apiProvider.overrideWithValue(api),
    apiPublicaProvider.overrideWithValue(api),
    sessaoInicialProvider.overrideWithValue(sessao),
  ]);
  addTearDown(container.dispose);
  final rotas = container.read(rotasProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: rotas),
  ));
  await tester.pumpAndSettle();
  return rotas;
}

Future<void> irPara(WidgetTester tester, GoRouter rotas, String local) async {
  rotas.go(local);
  await tester.pumpAndSettle();
}

void main() {
  group('sem aceitar o termo (LGPD)', () {
    testWidgets('abrir o app mostra o termo', (tester) async {
      await abrirApp(tester);
      expect(find.byType(ConsentimentoTela), findsOneWidget);
    });

    for (final local in const ['/', '/home', '/questionario', '/historico', '/entrar']) {
      testWidgets('não dá para pular o termo indo direto para $local', (tester) async {
        final rotas = await abrirApp(tester);
        await irPara(tester, rotas, local);
        expect(find.byType(ConsentimentoTela), findsOneWidget);
      });
    }
  });

  group('sem conta', () {
    testWidgets('abrir o app mostra o início, com a autoavaliação livre', (tester) async {
      await abrirApp(tester, prefs: _aceitou);
      expect(find.byType(InicioTela), findsOneWidget);
      expect(find.text('Fazer autoavaliação'), findsOneWidget);
    });

    testWidgets('a autoavaliação e o histórico continuam abertos', (tester) async {
      final rotas = await abrirApp(tester, prefs: _aceitou);
      await irPara(tester, rotas, '/questionario');
      expect(find.byType(QuestionarioTela), findsOneWidget);
      await irPara(tester, rotas, '/historico');
      expect(find.byType(HistoricoTela), findsOneWidget);
    });

    testWidgets('o painel pede login', (tester) async {
      final rotas = await abrirApp(tester, prefs: _aceitou);
      await irPara(tester, rotas, '/home');
      expect(find.byType(EntrarTela), findsOneWidget);
      expect(find.byType(HomeTela), findsNothing);
    });

    testWidgets('quem já aceitou não volta para o termo', (tester) async {
      final rotas = await abrirApp(tester, prefs: _aceitou);
      await irPara(tester, rotas, '/consentimento');
      expect(find.byType(InicioTela), findsOneWidget);
    });
  });

  group('com conta', () {
    testWidgets('abrir o app vai direto para a Home', (tester) async {
      await abrirApp(tester, prefs: _aceitou, sessao: _sessao);
      expect(find.byType(HomeTela), findsOneWidget);
      expect(find.byType(InicioTela), findsNothing);
    });

    testWidgets('"voltar ao início" (/) cai na Home', (tester) async {
      final rotas = await abrirApp(tester, prefs: _aceitou, sessao: _sessao);
      await irPara(tester, rotas, '/questionario');
      await irPara(tester, rotas, '/');
      expect(find.byType(HomeTela), findsOneWidget);
    });

    testWidgets('sair da conta pelo menu volta ao termo e o painel fica fechado', (tester) async {
      final rotas = await abrirApp(tester, prefs: _aceitou, sessao: _sessao);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentimentoTela), findsOneWidget);
      await irPara(tester, rotas, '/home');
      expect(find.byType(HomeTela), findsNothing);
    });

    testWidgets('apagar os dados pelo menu chama a API e volta ao termo', (tester) async {
      await abrirApp(tester, prefs: _aceitou, sessao: _sessao);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar meus dados'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentimentoTela), findsOneWidget);
    });

    testWidgets('cancelar a saída mantém na Home', (tester) async {
      await abrirApp(tester, prefs: _aceitou, sessao: _sessao);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeTela), findsOneWidget);
    });
  });
}
