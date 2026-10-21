import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_cliente.dart';
import 'models/questionario.dart';
import 'models/resultado.dart';

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

  @override
  Future<void> registrarUsuario(String usuarioId) async {}

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
