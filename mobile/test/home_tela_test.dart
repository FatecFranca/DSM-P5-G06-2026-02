import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/data/models/painel.dart';
import 'package:equilibra/data/models/resultado.dart';
import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/screens/home_tela.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'apoio/falsos.dart';

final _sessao = Sessao(token: 't', usuarioId: 'conta-1', email: 'ana@exemplo.com', expiraEm: DateTime(2099));

Painel _painel({String risco = 'medio', String? tendencia = 'melhorando', String? apoio, int total = 3}) => Painel(
      totalAvaliacoes: total,
      ultimaEm: DateTime(2026, 11, 5),
      riscoAtual: risco,
      tendencia: tendencia,
      probabilidadesMedias: const Probabilidades(baixo: 0.25, medio: 0.5, alto: 0.25),
      medias: const {
        'nota_semestre_anterior': 7.5,
        'horas_ia_semana': 12.5,
        'horas_estudo_semana': 8,
        'qtd_ferramentas_ia': 3,
        'dependencia_ia': 6.5,
        'ansiedade_provas': 7,
        'assinatura_paga': 0.5,
      },
      maisComuns: const {
        'area_curso': 'exatas',
        'ano_curso': 'terceiro_ano',
        'uso_principal_ia': 'respostas_prontas',
        'nivel_prompt': 'iniciante',
        'politica_instituicao': 'proibido',
      },
      referencias: const {'horas_ia_semana': 4.64, 'ansiedade_provas': 3.93},
      notaReferencias: 'As referências servem como orientação geral.',
      dicas: const [
        DicaPainel(titulo: 'Reduza aos poucos as horas de IA', texto: 'Você usa 12,5 h por semana.', tipo: 'melhorar'),
        DicaPainel(titulo: 'Continue assim', texto: 'Parabéns.', tipo: 'manter'),
      ],
      apoio: apoio,
      aviso: 'Não é um diagnóstico.',
    );

/// Monta a Home com a API falsa e rotas de destino simples.
Future<ProviderContainer> abrirHome(WidgetTester tester, ApiFalsa api) async {
  tester.view.physicalSize = const Size(800, 4000); // painel inteiro visível
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = await criarContainer(api, prefs: {'usuario_id': 'conta-1', 'consentiu': true}, sessao: _sessao);
  addTearDown(container.dispose);
  final rotas = GoRouter(initialLocation: '/home', routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeTela()),
    GoRoute(path: '/questionario', builder: (_, _) => const Scaffold(body: Text('QUESTIONARIO'))),
    GoRoute(path: '/historico', builder: (_, _) => const Scaffold(body: Text('HISTORICO'))),
    GoRoute(path: '/entrar', builder: (_, _) => const Scaffold(body: Text('ENTRAR'))),
    GoRoute(path: '/consentimento', builder: (_, _) => const Scaffold(body: Text('TERMO'))),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: rotas),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('sem avaliações: convida a fazer a primeira, sem mostrar médias', (tester) async {
    await abrirHome(tester, ApiFalsa());

    expect(find.text('Seu painel aparece aqui'), findsOneWidget);
    expect(find.text('Suas médias'), findsNothing);
    expect(find.text('Fazer autoavaliação'), findsOneWidget);
    expect(find.text('Conectado como ana@exemplo.com'), findsOneWidget);
  });

  testWidgets('mostra o risco atual, o total de avaliações e a data da última', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('Risco médio'), findsOneWidget);
    expect(find.text('3 avaliações'), findsOneWidget);
    expect(find.text('Última em 05/11/2026'), findsOneWidget);
  });

  testWidgets('uma avaliação só aparece no singular e sem tendência', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel(total: 1, tendencia: null));

    expect(find.text('1 avaliação'), findsOneWidget);
    expect(find.textContaining('avaliação anterior'), findsNothing);
  });

  for (final (tendencia, texto) in const [
    ('melhorando', 'Melhorando desde a avaliação anterior'),
    ('piorando', 'Piorou desde a avaliação anterior'),
    ('estavel', 'Estável desde a avaliação anterior'),
  ]) {
    testWidgets('tendência $tendencia aparece com texto', (tester) async {
      await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel(tendencia: tendencia));
      expect(find.text(texto), findsOneWidget);
    });
  }

  testWidgets('mostra as dicas do que pode melhorar', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('Dicas para você'), findsOneWidget);
    expect(find.text('Reduza aos poucos as horas de IA'), findsOneWidget);
    expect(find.text('Você usa 12,5 h por semana.'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget); // melhorar
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget); // manter
  });

  testWidgets('mostra as médias de todas as respostas numéricas, com vírgula e referência', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('12,5 h'), findsOneWidget);
    expect(find.text('Referência: 4,6 h'), findsOneWidget);
    expect(find.text('7,0 de 10'), findsOneWidget);
    expect(find.text('Referência: 3,9 de 10'), findsOneWidget);
    expect(find.text('6,5 de 10'), findsOneWidget);
    expect(find.text('8,0 h'), findsOneWidget);
    expect(find.text('7,5'), findsOneWidget);
    expect(find.text('3,0'), findsOneWidget);
    expect(find.text('50% das vezes'), findsOneWidget);
  });

  testWidgets('mostra a resposta mais comum em português, não o código interno', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('Obter respostas prontas'), findsOneWidget);
    expect(find.text('Exatas e tecnologia'), findsOneWidget);
    expect(find.text('3º ano'), findsOneWidget);
    expect(find.text('Iniciante'), findsOneWidget);
    expect(find.text('Proíbe o uso de IA'), findsOneWidget);
    expect(find.textContaining('respostas_prontas'), findsNothing);
  });

  testWidgets('mostra a chance média de cada nível', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('Chance média de cada nível'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('25%'), findsNWidgets(2));
  });

  testWidgets('aviso de que não é diagnóstico e a nota das referências aparecem sempre', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

    expect(find.text('Não é um diagnóstico.'), findsOneWidget);
    expect(find.text('As referências servem como orientação geral.'), findsOneWidget);
  });

  testWidgets('contato do CVV aparece quando vem da API', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel(risco: 'alto', apoio: 'CVV: ligue 188'));
    expect(find.text('Precisa conversar?'), findsOneWidget);
    expect(find.text('CVV: ligue 188'), findsOneWidget);
  });

  testWidgets('sem risco alto não mostra o contato do CVV', (tester) async {
    await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());
    expect(find.text('Precisa conversar?'), findsNothing);
  });

  testWidgets('botão leva à autoavaliação', (tester) async {
    await abrirHome(tester, ApiFalsa());

    await tester.tap(find.text('Fazer autoavaliação'));
    await tester.pumpAndSettle();
    expect(find.text('QUESTIONARIO'), findsOneWidget);
  });

  testWidgets('botão leva ao histórico', (tester) async {
    await abrirHome(tester, ApiFalsa());

    await tester.tap(find.text('Meu histórico'));
    await tester.pumpAndSettle();
    expect(find.text('HISTORICO'), findsOneWidget);
  });

  group('puxar a tela para atualizar', () {
    // A tela de teste é bem alta (4000 px) e o indicador só dispara depois de 1/6 da altura.
    const puxar = Offset(0, 1500);

    testWidgets('busca o painel de novo e mostra os dados novos', (tester) async {
      final api = ApiFalsa()..painelDevolvido = _painel();
      await abrirHome(tester, api);
      expect(find.text('Risco médio'), findsOneWidget);

      api.painelDevolvido = _painel(risco: 'baixo');
      await tester.fling(find.text('Olá!'), puxar, 1000);
      await tester.pumpAndSettle();

      expect(find.text('Risco baixo'), findsOneWidget);
    });

    testWidgets('sem conexão: mostra o erro na tela, sem deixar exceção solta', (tester) async {
      final api = ApiFalsa()..painelDevolvido = _painel();
      await abrirHome(tester, api);

      api.erroDados = ErroApi('Sem conexão com o servidor.');
      await tester.fling(find.text('Olá!'), puxar, 1000);
      await tester.pumpAndSettle();

      expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
      expect(find.byType(RefreshProgressIndicator), findsNothing, reason: 'o indicador precisa sumir');
    });
  });

  group('menu da conta', () {
    Future<void> escolher(WidgetTester tester, String opcao) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcao));
      await tester.pumpAndSettle();
    }

    testWidgets('sair pede confirmação; ao cancelar, continua na conta', (tester) async {
      final c = await abrirHome(tester, ApiFalsa()..painelDevolvido = _painel());

      await escolher(tester, 'Sair da conta');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c.read(sessaoProvider), isNotNull);
      expect(find.text('Risco médio'), findsOneWidget);
    });

    testWidgets('sair encerra a sessão e volta ao termo, sem apagar nada no servidor', (tester) async {
      final api = ApiFalsa()..painelDevolvido = _painel();
      final c = await abrirHome(tester, api);

      await escolher(tester, 'Sair da conta');
      await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(c.read(sessaoProvider), isNull);
      expect(find.text('TERMO'), findsOneWidget);
      expect(api.chamadas, isNot(contains('apagarDados')));
    });

    testWidgets('apagar os dados pede confirmação, apaga no servidor e volta ao termo', (tester) async {
      final api = ApiFalsa()..painelDevolvido = _painel();
      final c = await abrirHome(tester, api);

      await escolher(tester, 'Apagar meus dados');
      expect(api.chamadas, isNot(contains('apagarDados')), reason: 'nada antes de confirmar');
      await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
      await tester.pumpAndSettle();

      expect(api.chamadas, contains('apagarDados'));
      expect(c.read(sessaoProvider), isNull);
      expect(find.text('TERMO'), findsOneWidget);
    });
  });

  group('erros ao carregar o painel', () {
    testWidgets('sessão expirada oferece entrar de novo', (tester) async {
      await abrirHome(tester, ApiFalsa()..erroDados = ErroSessao('Sessão inválida ou expirada.'));

      expect(find.text('Sessão inválida ou expirada.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('ENTRAR'), findsOneWidget);
    });

    testWidgets('servidor não reconhece o aparelho: volta ao termo', (tester) async {
      await abrirHome(tester, ApiFalsa()..erroDados = ErroCadastroAusente());

      await tester.tap(find.text('Aceitar o termo de novo'));
      await tester.pumpAndSettle();
      expect(find.text('TERMO'), findsOneWidget);
    });

    testWidgets('sem conexão: permite tentar de novo, e funciona quando a conexão volta', (tester) async {
      final api = ApiFalsa()..erroDados = ErroApi('Sem conexão com o servidor.');
      await abrirHome(tester, api);
      expect(find.text('Sem conexão com o servidor.'), findsOneWidget);

      api
        ..erroDados = null
        ..painelDevolvido = _painel();
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Risco médio'), findsOneWidget);
    });

    testWidgets('erro interno nunca aparece cru', (tester) async {
      final api = ApiFalsa()..painelErroInterno = StateError('falha interna');
      await abrirHome(tester, api);

      expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });
}
