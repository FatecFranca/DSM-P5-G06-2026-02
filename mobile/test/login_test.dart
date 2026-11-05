// Fluxo de login com os provedores REAIS do app: só a rede é falsa.
// Cobre o que foi visto no emulador contra a API real.
import 'package:dio/dio.dart';
import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/data/sessao_armazenamento.dart';
import 'package:equilibra/screens/entrar_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio/falsos.dart';

const _sessaoJson = {
  'token': 'token-real',
  'tipo': 'bearer',
  'expira_em': '2099-01-01T00:00:00Z',
  'usuario_id': 'id-da-conta',
  'email': 'ana@exemplo.com',
};

ResponseBody loginOk(RequestOptions pedido) =>
    pedido.path == '/auth/login' ? resposta(200, _sessaoJson) : resposta(200, []);

const _anonimo = {'usuario_id': 'anon-1', 'consentiu': true};

Future<ProviderContainer> abrirEntrar(WidgetTester tester, AdaptadorFalso rede) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = await criarContainerComRede(rede, prefs: _anonimo);
  addTearDown(container.dispose);
  final rotas = GoRouter(initialLocation: '/entrar', routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('INICIO'))),
    GoRoute(path: '/entrar', builder: (_, _) => const EntrarTela(modoInicial: ModoConta.entrar)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: rotas),
  ));
  return container;
}

Future<void> tentarEntrar(WidgetTester tester, {String email = 'ana@exemplo.com', String senha = 'senha-certa-1'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), senha);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

/// Armazenamento seguro que falha, como pode acontecer depois de restaurar um backup no Android.
class ArmazenamentoQuebrado implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation chamada) => Future<Never>.error(PlatformException(code: 'chave-ilegivel'));
}

void main() {
  group('login na tela', () {
    testWidgets('senha certa: entra, guarda a sessão e adota o id da conta', (tester) async {
      final rede = AdaptadorFalso(loginOk);
      final c = await abrirEntrar(tester, rede);

      await tentarEntrar(tester, email: ' Ana@Exemplo.COM ');

      expect(find.text('INICIO'), findsOneWidget);
      expect(find.text('Bem-vindo de volta!'), findsOneWidget);
      final corpo = rede.pedidos.single.data as Map<String, dynamic>;
      expect(corpo['email'], 'ana@exemplo.com'); // sem espaços e em minúsculas
      expect(corpo['usuario_id_anonimo'], 'anon-1'); // une o histórico anônimo do aparelho
      expect(c.read(sessaoProvider)?.token, 'token-real');
      expect(c.read(armazenamentoProvider).usuarioId, 'id-da-conta');
      expect(c.read(armazenamentoProvider).emailDaConta, 'ana@exemplo.com');
    });

    testWidgets('senha errada: mostra a mensagem da API, não muda nada e continua na tela', (tester) async {
      final rede = AdaptadorFalso((_) => resposta(401, {'detail': 'E-mail ou senha incorretos.'}));
      final c = await abrirEntrar(tester, rede);

      await tentarEntrar(tester, senha: 'errada');

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.byType(EntrarTela), findsOneWidget);
      expect(c.read(sessaoProvider), isNull);
      expect(c.read(armazenamentoProvider).usuarioId, 'anon-1');
    });

    testWidgets('bloqueio por muitas tentativas: mostra a mensagem da API', (tester) async {
      final rede = AdaptadorFalso((_) => resposta(429, {'detail': 'Muitas tentativas de login.'}));
      await abrirEntrar(tester, rede);

      await tentarEntrar(tester);

      expect(find.text('Muitas tentativas de login.'), findsOneWidget);
    });

    testWidgets('e-mail que a API recusa (422): mensagem que faz sentido no login', (tester) async {
      final rede = AdaptadorFalso((_) => resposta(422, {'detail': [{'msg': 'value is not a valid email'}]}));
      await abrirEntrar(tester, rede);

      await tentarEntrar(tester, email: 'ana@empresa.local');

      expect(find.textContaining('Confira o e-mail e a senha'), findsOneWidget);
      expect(find.textContaining('fora do esperado'), findsNothing);
    });

    testWidgets('sem conexão: avisa e permite tentar de novo', (tester) async {
      final rede = AdaptadorFalso((p) => throw DioException.connectionError(requestOptions: p, reason: 'offline'));
      await abrirEntrar(tester, rede);

      await tentarEntrar(tester);

      expect(find.textContaining('Sem conexão'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Entrar')).onPressed, isNotNull);
    });

    testWidgets('aviso novo substitui o anterior na hora, sem fila de mensagens atrasadas', (tester) async {
      var tentativa = 0;
      final rede = AdaptadorFalso((_) => ++tentativa == 1
          ? resposta(401, {'detail': 'E-mail ou senha incorretos.'})
          : resposta(429, {'detail': 'Muitas tentativas de login.'}));
      await abrirEntrar(tester, rede);

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'errada');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump(const Duration(milliseconds: 500)); // bem antes dos 4 s do aviso anterior

      expect(find.text('Muitas tentativas de login.'), findsOneWidget);
      expect(find.text('E-mail ou senha incorretos.'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('campo de e-mail sem corretor automático do teclado', (tester) async {
      await abrirEntrar(tester, AdaptadorFalso(loginOk));

      final campo = tester.widget<TextField>(
        find.descendant(of: find.widgetWithText(TextFormField, 'E-mail'), matching: find.byType(TextField)),
      );
      expect(campo.autocorrect, isFalse);
      expect(campo.enableSuggestions, isFalse);
    });

    testWidgets('senha fica escondida até pedir para mostrar', (tester) async {
      await abrirEntrar(tester, AdaptadorFalso(loginOk));
      TextField senha() => tester.widget<TextField>(
            find.descendant(of: find.widgetWithText(TextFormField, 'Senha'), matching: find.byType(TextField)),
          );

      expect(senha().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(senha().obscureText, isFalse);
    });
  });

  group('sessão entre aberturas do app', () {
    test('reabrir o app logado continua conectado e usa o token', () async {
      final rede = AdaptadorFalso(loginOk);
      final primeira = await criarContainerComRede(rede, prefs: _anonimo);
      await primeira.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1');
      primeira.dispose();

      // Como o main.dart faz ao abrir: lê a sessão salva e entrega ao app (mesmo aparelho).
      final salva = await SessaoArmazenamento().carregar();
      final dio = Dio(BaseOptions(baseUrl: 'http://api'))..httpClientAdapter = rede;
      final segunda = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
        dioProvider.overrideWithValue(dio),
        sessaoInicialProvider.overrideWithValue(salva),
      ]);
      addTearDown(segunda.dispose);

      expect(segunda.read(sessaoProvider)?.email, 'ana@exemplo.com');
      expect(segunda.read(armazenamentoProvider).usuarioId, 'id-da-conta');
      await segunda.read(apiProvider).historico('id-da-conta');
      expect(rede.pedidos.last.headers['Authorization'], 'Bearer token-real');
    });

    test('sessão vencida ao abrir: fica sem login, mas o app sabe de qual conta era', () async {
      final rede = AdaptadorFalso((_) => resposta(200, {..._sessaoJson, 'expira_em': '2000-01-01T00:00:00Z'}));
      final c = await criarContainerComRede(rede, prefs: _anonimo);
      addTearDown(c.dispose);
      await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1');

      expect(await SessaoArmazenamento().carregar(), isNull);
      expect(c.read(armazenamentoProvider).emailDaConta, 'ana@exemplo.com'); // para o aviso de sessão expirada
    });

    test('sair: o token some e a próxima abertura está sem login', () async {
      final c = await criarContainerComRede(AdaptadorFalso(loginOk), prefs: _anonimo);
      addTearDown(c.dispose);
      await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1');

      await c.read(sessaoProvider.notifier).sair();

      expect(c.read(sessaoProvider), isNull);
      expect(await SessaoArmazenamento().carregar(), isNull);
      expect(c.read(armazenamentoProvider).consentiu, isFalse);
    });

    test('depois de sair, o próximo pedido à API vai sem o token antigo', () async {
      final rede = AdaptadorFalso(loginOk);
      final c = await criarContainerComRede(rede, prefs: _anonimo);
      addTearDown(c.dispose);
      await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1');
      await c.read(sessaoProvider.notifier).sair();

      await c.read(apiProvider).historico('qualquer');

      expect(rede.pedidos.last.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('armazenamento seguro indisponível (ex.: backup restaurado)', () {
    final sessao = Sessao(token: 't', usuarioId: 'u', email: 'a@b.com', expiraEm: DateTime(2099));

    test('nada quebra: carregar devolve null; salvar e apagar não lançam erro', () async {
      final armazenamento = SessaoArmazenamento(ArmazenamentoQuebrado());

      expect(await armazenamento.carregar(), isNull);
      await armazenamento.salvar(sessao);
      await armazenamento.apagar();
    });

    test('o login funciona assim mesmo: a sessão vale enquanto o app estiver aberto', () async {
      SharedPreferences.setMockInitialValues(_anonimo);
      final dio = Dio(BaseOptions(baseUrl: 'http://api'))..httpClientAdapter = AdaptadorFalso(loginOk);
      final c = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
        dioProvider.overrideWithValue(dio),
        sessaoArmazenamentoProvider.overrideWithValue(SessaoArmazenamento(ArmazenamentoQuebrado())),
      ]);
      addTearDown(c.dispose);

      await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1');

      expect(c.read(sessaoProvider)?.token, 'token-real');
    });
  });
}
