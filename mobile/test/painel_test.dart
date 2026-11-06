// Modelo do painel, modo demo e ligação REAL entre login, API e Home (só a rede é falsa).
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equilibra/data/api_demo.dart';
import 'package:equilibra/data/models/painel.dart';
import 'package:equilibra/data/models/questionario.dart';
import 'package:equilibra/screens/home_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoio/falsos.dart';

/// Resposta no formato real de GET /usuarios/{id}/painel.
const _painelJson = {
  'total_avaliacoes': 2,
  'primeira_em': '2026-11-01T10:00:00Z',
  'ultima_em': '2026-11-05T10:00:00Z',
  'risco_atual': 'alto',
  'tendencia': 'piorando',
  'contagem_risco': {'baixo': 1, 'medio': 0, 'alto': 1},
  'probabilidades_medias': {'baixo': 0.3, 'medio': 0.2, 'alto': 0.5},
  'medias': {'horas_ia_semana': 20, 'ansiedade_provas': 7.5, 'assinatura_paga': 0.5},
  'mais_comuns': {'uso_principal_ia': 'gerar_ideias'},
  'referencias_risco_baixo': {'horas_ia_semana': 4.64},
  'nota_referencias': 'Orientação geral.',
  'dicas': [
    {'titulo': 'Reduza', 'texto': 'Texto', 'tipo': 'melhorar', 'variavel': 'horas_ia_semana'},
  ],
  'apoio': 'CVV 188',
  'aviso': 'Não é diagnóstico',
};

const _sessaoJson = {
  'token': 'token-real',
  'tipo': 'bearer',
  'expira_em': '2099-01-01T00:00:00Z',
  'usuario_id': 'id-da-conta',
  'email': 'ana@exemplo.com',
};

Questionario _ruim() => Questionario()
  ..horasIaSemana = 30
  ..horasEstudoSemana = 2
  ..dependenciaIa = 9
  ..ansiedadeProvas = 9
  ..usoPrincipalIa = 'respostas_prontas';

Questionario _bom() => Questionario()
  ..horasIaSemana = 3
  ..horasEstudoSemana = 15
  ..dependenciaIa = 2
  ..ansiedadeProvas = 3
  ..notaSemestreAnterior = 9;

void main() {
  group('Painel.fromJson', () {
    test('lê a resposta completa da API (números inteiros também)', () {
      final p = Painel.fromJson(_painelJson);
      expect(p.totalAvaliacoes, 2);
      expect(p.vazio, isFalse);
      expect(p.riscoAtual, 'alto');
      expect(p.tendencia, 'piorando');
      expect(p.medias['horas_ia_semana'], 20.0);
      expect(p.medias['assinatura_paga'], 0.5);
      expect(p.referencias['horas_ia_semana'], 4.64);
      expect(p.probabilidadesMedias?.alto, 0.5);
      expect(p.dicas.single.titulo, 'Reduza');
      expect(p.dicas.single.ehParaManter, isFalse);
      expect(p.apoio, 'CVV 188');
      expect(p.ultimaEm, isNotNull);
    });

    test('lê o painel de quem ainda não tem avaliações', () {
      final p = Painel.fromJson(const {
        'total_avaliacoes': 0,
        'primeira_em': null,
        'ultima_em': null,
        'risco_atual': null,
        'tendencia': null,
        'contagem_risco': <String, int>{},
        'probabilidades_medias': null,
        'medias': <String, double>{},
        'mais_comuns': <String, String>{},
        'referencias_risco_baixo': {'horas_ia_semana': 4.64},
        'nota_referencias': 'Orientação geral.',
        'dicas': <Map<String, dynamic>>[],
        'apoio': null,
        'aviso': 'Não é diagnóstico',
      });
      expect(p.vazio, isTrue);
      expect(p.dicas, isEmpty);
      expect(p.ultimaEm, isNull);
    });
  });

  group('ligação real: login → API com token → Home', () {
    testWidgets('a Home pede o painel à API com o token e mostra o resultado', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final rede = AdaptadorFalso((pedido) {
        if (pedido.path == '/auth/login') return resposta(200, _sessaoJson);
        return resposta(200, _painelJson);
      });
      final c = await criarContainerComRede(rede, prefs: {'usuario_id': 'anon-1', 'consentiu': true});
      addTearDown(c.dispose);
      // runAsync: dentro de testWidgets o relógio é simulado e os timers do Dio não disparariam.
      await tester.runAsync(
        () => c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1'),
      );

      final rotas = GoRouter(initialLocation: '/home', routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeTela()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: rotas),
      ));
      await tester.pumpAndSettle();

      final pedido = rede.pedidos.last;
      expect(pedido.path, '/usuarios/id-da-conta/painel'); // o id da conta, não o anônimo
      expect(pedido.headers['Authorization'], 'Bearer token-real');
      expect(find.text('Risco alto'), findsOneWidget);
      expect(find.text('Piorou desde a avaliação anterior'), findsOneWidget);
      expect(find.text('Reduza'), findsOneWidget);
    });

    // Bug visto no log da API: ao sair, com a Home ainda na tela, o painel recarregava. Isso criava
    // um id anônimo novo e o enviava ao servidor (401) antes de o usuário aceitar o termo de novo.
    testWidgets('ao sair da conta, nada vai para a API antes do novo aceite do termo', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final rede = AdaptadorFalso((pedido) {
        if (pedido.path == '/auth/login') return resposta(200, _sessaoJson);
        return resposta(200, _painelJson);
      });
      final c = await criarContainerComRede(rede, prefs: {'usuario_id': 'anon-1', 'consentiu': true});
      addTearDown(c.dispose);
      await tester.runAsync(
        () => c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'senha-certa-1'),
      );
      final rotas = GoRouter(initialLocation: '/home', routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeTela()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: rotas),
      ));
      await tester.pumpAndSettle();
      final pedidosAntes = rede.pedidos.length;

      await tester.runAsync(() => c.read(sessaoProvider.notifier).sair());
      await tester.pumpAndSettle();

      expect(rede.pedidos.length, pedidosAntes, reason: 'nenhuma chamada nova depois de sair');
      expect(c.read(prefsProvider).getString('usuario_id'), isNull, reason: 'nenhum id novo antes do termo');
      // Enquanto a tela sai, não pisca o painel da conta nem uma mensagem de erro.
      expect(find.text('Risco alto'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsNothing);
    });
  });

  group('modo demo', () {
    late ApiDemo api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = ApiDemo(await SharedPreferences.getInstance());
    });

    test('referências são as mesmas da API (backend/app/referencias_base.json)', () {
      final arquivo = File('../backend/app/referencias_base.json');
      final dados = jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
      expect(ApiDemo.referenciasRiscoBaixo, dados['media_risco_baixo']);
      expect(ApiDemo.desviosDaBase, dados['desvio']);
    });

    test('sem avaliações: painel vazio com aviso', () async {
      final p = await api.painel('x');
      expect(p.vazio, isTrue);
      expect(p.aviso, isNotEmpty);
    });

    test('calcula as médias e a resposta mais comum', () async {
      await api.prever('x', _ruim()..assinaturaPaga = true);
      await api.prever('x', _ruim()..horasIaSemana = 10);

      final p = await api.painel('x');

      expect(p.totalAvaliacoes, 2);
      expect(p.medias['horas_ia_semana'], 20);
      expect(p.medias['ansiedade_provas'], 9);
      expect(p.medias['assinatura_paga'], 0.5);
      expect(p.maisComuns['uso_principal_ia'], 'respostas_prontas');
    });

    test('hábitos ruins recebem dicas com os números; hábitos bons, dica de manter', () async {
      await api.prever('x', _ruim());
      final ruim = await api.painel('x');
      expect(ruim.dicas.length, 5); // 4 respostas + uso para respostas prontas
      expect(ruim.dicas.first.titulo, 'Pratique estudar sem a IA'); // a maior diferença vem primeiro
      expect(ruim.dicas.map((d) => d.texto).join(), contains('30,0 h'));
      expect(ruim.dicas.every((d) => !d.ehParaManter), isTrue);

      await api.apagarDados('x');
      await api.prever('x', _bom());
      final bom = await api.painel('x');
      expect(bom.dicas.single.ehParaManter, isTrue);
    });

    test('risco atual, tendência e contato do CVV seguem a última avaliação', () async {
      await api.prever('x', _ruim());
      expect((await api.painel('x')).apoio, contains('188'));
      expect((await api.painel('x')).tendencia, isNull);

      await api.prever('x', _bom());
      final p = await api.painel('x');
      expect(p.riscoAtual, 'baixo');
      expect(p.tendencia, 'melhorando');
      expect(p.apoio, isNull);
    });

    test('avaliações antigas, sem as respostas completas, não quebram o painel', () async {
      SharedPreferences.setMockInitialValues({
        'demo_historico': jsonEncode([
          {
            'id': 1,
            'criado_em': '2026-10-20T10:00:00',
            'nivel_risco': 'baixo',
            'probabilidades': {'baixo': 0.6, 'medio': 0.3, 'alto': 0.1},
            'horas_ia_semana': 5,
            'ansiedade_provas': 4,
          },
        ]),
      });
      final antiga = ApiDemo(await SharedPreferences.getInstance());
      expect((await antiga.painel('x')).vazio, isTrue);
      expect(await antiga.historico('x'), hasLength(1));
    });
  });

  test('dioProvider real usa a chave da API e o endereço configurado', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final Dio dio = c.read(dioProvider);
    expect(dio.options.headers['X-API-Key'], isNotEmpty);
    expect(dio.options.baseUrl, isNotEmpty);
  });
}
