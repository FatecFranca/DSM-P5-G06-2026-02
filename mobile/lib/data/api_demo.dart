import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_cliente.dart';
import 'models/painel.dart';
import 'models/questionario.dart';
import 'models/resultado.dart';
import 'models/sessao.dart';

/// Substitui a API quando o app roda com --dart-define=MODO_DEMO=true.
///
/// Serve para apresentar o app sem o servidor no ar. A classificação aqui é uma
/// regra simples escrita à mão, NÃO o modelo de ML treinado — o resultado real
/// só vem da API. Textos de orientação, apoio e aviso são os mesmos da API.
class ApiDemo implements ApiCliente {
  ApiDemo(this._prefs);

  final SharedPreferences _prefs;
  static const _chaveHistorico = 'demo_historico';

  static const _aviso = 'Esta é uma autoavaliação educativa, não um diagnóstico. '
      'Em caso de sofrimento, procure um profissional de saúde.';
  static const _apoio =
      'CVV – Centro de Valorização da Vida: ligue 188 (gratuito, 24h) ou acesse cvv.org.br.';
  static const _orientacoes = {
    'baixo': [
      'Seu equilíbrio parece bom. Mantenha pausas regulares nos estudos.',
      'Continue usando a IA como apoio, não como substituta do seu raciocínio.',
    ],
    'medio': [
      'Reserve blocos de estudo sem IA para fixar o conteúdo.',
      'Faça pausas curtas a cada 50 minutos de estudo.',
      'Observe se a ansiedade antes das provas está aumentando.',
    ],
    'alto': [
      'Reduza gradualmente as horas de uso de IA e alterne com estudo ativo.',
      'Converse com alguém de confiança ou com o apoio da sua instituição.',
      'Durma bem e evite estudar até tarde na véspera das provas.',
    ],
  };

  /// Médias dos estudantes de risco baixo e desvios da base de treino: os mesmos valores de
  /// backend/app/referencias_base.json (um teste confere que continuam iguais).
  static const referenciasRiscoBaixo = {
    'nota_semestre_anterior': 8.01,
    'horas_ia_semana': 4.64,
    'horas_estudo_semana': 11.97,
    'qtd_ferramentas_ia': 2.79,
    'dependencia_ia': 2.82,
    'ansiedade_provas': 3.93,
    'assinatura_paga': 0.37,
  };
  static const desviosDaBase = {
    'nota_semestre_anterior': 1.2,
    'horas_ia_semana': 8.27,
    'horas_estudo_semana': 5.16,
    'qtd_ferramentas_ia': 1.19,
    'dependencia_ia': 1.82,
    'ansiedade_provas': 2.14,
    'assinatura_paga': 0.49,
  };
  static const _notaReferencias = 'As referências são a média dos estudantes de risco baixo na base usada '
      'para treinar o modelo (provavelmente sintética). Servem como orientação geral, não como meta.';
  static const _perguntasDeEscolha = [
    'area_curso',
    'ano_curso',
    'uso_principal_ia',
    'nivel_prompt',
    'politica_instituicao',
  ];
  static final _regrasDeDica = <(String, String, String Function(String, String))>[
    (
      'horas_ia_semana',
      'Reduza aos poucos as horas de IA',
      (m, r) => 'Você usa IA em média $m h por semana; entre estudantes de risco baixo, a média é $r h. '
          'Troque parte desse tempo por estudo ativo: resolva exercícios e explique o conteúdo com suas palavras.',
    ),
    (
      'dependencia_ia',
      'Pratique estudar sem a IA',
      (m, r) => 'Sua dependência de IA está em $m de 10 (referência: $r). Antes de pedir ajuda, tente '
          'resolver sozinho por 15 minutos e use a IA só para conferir.',
    ),
    (
      'ansiedade_provas',
      'Cuide da ansiedade antes das provas',
      (m, r) => 'Sua ansiedade em provas está em $m de 10 (referência: $r). Faça revisões curtas ao longo '
          'da semana e durma bem na véspera. Se ela atrapalhar sua rotina, procure o apoio da sua '
          'instituição ou um profissional de saúde.',
    ),
    (
      'horas_estudo_semana',
      'Reserve mais tempo de estudo sem IA',
      (m, r) => 'Você estuda sem IA $m h por semana; a referência é $r h. Comece com blocos fixos de '
          '50 minutos na agenda e aumente aos poucos.',
    ),
  ];

  @override
  Future<void> registrarUsuario(String usuarioId) async {}

  /// No demo não há servidor de contas: qualquer e-mail e senha válidos entram,
  /// e o aparelho continua com o mesmo histórico local.
  @override
  Future<Sessao> cadastrar({
    required String usuarioId,
    required String email,
    required String senha,
  }) async =>
      _sessaoSimulada(usuarioId, email);

  @override
  Future<Sessao> entrar({
    required String email,
    required String senha,
    String? usuarioIdAnonimo,
  }) async =>
      _sessaoSimulada(usuarioIdAnonimo ?? const Uuid().v4(), email);

  Sessao _sessaoSimulada(String usuarioId, String email) => Sessao(
        token: 'token-demo',
        usuarioId: usuarioId,
        email: email.toLowerCase(),
        expiraEm: DateTime.now().add(const Duration(days: 7)),
      );

  @override
  Future<Resultado> prever(String usuarioId, Questionario respostas) async {
    await Future<void>.delayed(const Duration(milliseconds: 600)); // simula a rede
    final p = _estimar(respostas);
    final nivel = (p.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final itens = _lerHistorico();
    final agora = DateTime.now();
    final id = itens.length + 1;

    itens.insert(0, {
      'id': id,
      'criado_em': agora.toIso8601String(),
      'nivel_risco': nivel,
      'probabilidades': p,
      'horas_ia_semana': respostas.horasIaSemana,
      'ansiedade_provas': respostas.ansiedadeProvas,
      'respostas': respostas.toJson(), // usadas pelo painel
    });
    await _prefs.setString(_chaveHistorico, jsonEncode(itens));

    return Resultado(
      avaliacaoId: id,
      nivelRisco: nivel,
      probabilidades: Probabilidades.fromJson(p),
      orientacoes: _orientacoes[nivel]!,
      apoio: nivel == 'alto' ? _apoio : null,
      aviso: _aviso,
      criadoEm: agora,
    );
  }

  @override
  Future<List<AvaliacaoResumo>> historico(String usuarioId) async =>
      _lerHistorico().map(AvaliacaoResumo.fromJson).toList();

  @override
  Future<void> apagarDados(String usuarioId) => _prefs.remove(_chaveHistorico);

  /// Mesma conta da API (backend/app/painel.py), a partir das avaliações guardadas no aparelho.
  @override
  Future<Painel> painel(String usuarioId) async {
    // Avaliações antigas do modo demo não guardavam as respostas completas: ficam de fora.
    final itens = _lerHistorico().where((i) => i['respostas'] != null).toList().reversed.toList();
    if (itens.isEmpty) {
      return Painel(
        totalAvaliacoes: 0,
        referencias: referenciasRiscoBaixo,
        notaReferencias: _notaReferencias,
        aviso: _aviso,
      );
    }

    final respostas = [for (final i in itens) i['respostas'] as Map<String, dynamic>];
    double media(num Function(Map<String, dynamic>) valor) =>
        double.parse((respostas.map(valor).reduce((a, b) => a + b) / respostas.length).toStringAsFixed(2));
    final medias = {
      for (final nome in referenciasRiscoBaixo.keys.where((n) => n != 'assinatura_paga'))
        nome: media((r) => r[nome] as num),
      'assinatura_paga': media((r) => r['assinatura_paga'] == true ? 1 : 0),
    };
    final maisComuns = {
      for (final nome in _perguntasDeEscolha)
        nome: _maisComum([for (final r in respostas) r[nome] as String]),
    };
    double probabilidade(String nivel) {
      final soma = itens.map((i) => ((i['probabilidades'] as Map)[nivel] as num)).reduce((a, b) => a + b);
      return double.parse((soma / itens.length).toStringAsFixed(2));
    }

    final risco = itens.last['nivel_risco'] as String;
    return Painel(
      totalAvaliacoes: itens.length,
      ultimaEm: DateTime.parse(itens.last['criado_em'] as String),
      riscoAtual: risco,
      tendencia: _tendencia(itens),
      probabilidadesMedias: Probabilidades(
        baixo: probabilidade('baixo'),
        medio: probabilidade('medio'),
        alto: probabilidade('alto'),
      ),
      medias: medias,
      maisComuns: maisComuns,
      referencias: referenciasRiscoBaixo,
      notaReferencias: _notaReferencias,
      dicas: _dicas(medias, maisComuns),
      apoio: risco == 'alto' ? _apoio : null,
      aviso: _aviso,
    );
  }

  String? _tendencia(List<Map<String, dynamic>> itens) {
    if (itens.length < 2) return null;
    num alto(Map<String, dynamic> i) => (i['probabilidades'] as Map)['alto'] as num;
    final mudanca = alto(itens.last) - alto(itens[itens.length - 2]);
    if (mudanca <= -0.05) return 'melhorando';
    if (mudanca >= 0.05) return 'piorando';
    return 'estavel';
  }

  /// Resposta mais frequente; no empate, a mais recente ([valores] em ordem cronológica).
  String _maisComum(List<String> valores) {
    final contagem = <String, int>{};
    for (final v in valores) {
      contagem[v] = (contagem[v] ?? 0) + 1;
    }
    final maior = contagem.values.reduce(max);
    return valores.lastWhere((v) => contagem[v] == maior);
  }

  List<DicaPainel> _dicas(Map<String, double> medias, Map<String, String> maisComuns) {
    String numero(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final candidatas = <(double, DicaPainel)>[];
    for (final regra in _regrasDeDica) {
      final variavel = regra.$1;
      final media = medias[variavel]!;
      final referencia = referenciasRiscoBaixo[variavel]!;
      final distancia = (variavel == 'horas_estudo_semana' ? referencia - media : media - referencia) /
          desviosDaBase[variavel]!;
      if (distancia > 0.25) {
        candidatas.add((
          distancia,
          DicaPainel(titulo: regra.$2, texto: regra.$3(numero(media), numero(referencia)), tipo: 'melhorar'),
        ));
      }
    }
    candidatas.sort((a, b) => b.$1.compareTo(a.$1));
    final dicas = [for (final c in candidatas) c.$2];
    if (maisComuns['uso_principal_ia'] == 'respostas_prontas') {
      dicas.add(const DicaPainel(
        titulo: 'Use a IA para aprender, não só para ter a resposta',
        texto: 'Seu uso mais comum é obter respostas prontas. Peça explicações e exemplos, e tente '
            'refazer o exercício sem olhar: é assim que o conteúdo fica.',
        tipo: 'melhorar',
      ));
    }
    if (dicas.isNotEmpty) return dicas;
    return const [
      DicaPainel(
        titulo: 'Seus hábitos estão no caminho certo',
        texto: 'Suas médias estão próximas das de estudantes com risco baixo. Continue com as pausas '
            'regulares e usando a IA como apoio, não como substituta do seu raciocínio.',
        tipo: 'manter',
      ),
    ];
  }

  List<Map<String, dynamic>> _lerHistorico() {
    final texto = _prefs.getString(_chaveHistorico);
    if (texto == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(texto) as List);
  }

  /// Pontuação de 0 a 1 a partir de ansiedade, dependência de IA e carga de horas,
  /// convertida em probabilidades dos três níveis.
  Map<String, double> _estimar(Questionario q) {
    final ansiedade = (q.ansiedadeProvas - 1) / 9;
    final dependencia = (q.dependenciaIa - 1) / 9;
    final horasIa = min(q.horasIaSemana / 40, 1.0);
    final poucoEstudo = 1 - min(q.horasEstudoSemana / 20, 1.0);
    final notaBaixa = 1 - q.notaSemestreAnterior / 10;
    final s = 0.35 * ansiedade + 0.25 * dependencia + 0.2 * horasIa +
        0.1 * poucoEstudo + 0.1 * notaBaixa;

    // Cada nível "puxa" para um ponto da escala; softmax transforma em probabilidades.
    final brutos = {
      'baixo': exp(-pow((s - 0.15) * 5, 2)),
      'medio': exp(-pow((s - 0.45) * 5, 2)),
      'alto': exp(-pow((s - 0.75) * 5, 2)),
    };
    final total = brutos.values.reduce((a, b) => a + b);
    return brutos.map((k, v) => MapEntry(k, double.parse((v / total).toStringAsFixed(4))));
  }
}
