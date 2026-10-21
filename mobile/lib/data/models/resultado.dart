/// Probabilidade de cada nível de risco, de 0 a 1.
class Probabilidades {
  final double baixo;
  final double medio;
  final double alto;

  const Probabilidades({required this.baixo, required this.medio, required this.alto});

  factory Probabilidades.fromJson(Map<String, dynamic> json) => Probabilidades(
        baixo: (json['baixo'] as num).toDouble(),
        medio: (json['medio'] as num).toDouble(),
        alto: (json['alto'] as num).toDouble(),
      );
}

/// Resposta de POST /predicoes.
class Resultado {
  final int avaliacaoId;
  final String nivelRisco;
  final Probabilidades probabilidades;
  final List<String> orientacoes;
  final String? apoio;
  final String aviso;
  final DateTime criadoEm;

  const Resultado({
    required this.avaliacaoId,
    required this.nivelRisco,
    required this.probabilidades,
    required this.orientacoes,
    required this.apoio,
    required this.aviso,
    required this.criadoEm,
  });

  factory Resultado.fromJson(Map<String, dynamic> json) => Resultado(
        avaliacaoId: json['avaliacao_id'] as int,
        nivelRisco: json['nivel_risco'] as String,
        probabilidades: Probabilidades.fromJson(json['probabilidades'] as Map<String, dynamic>),
        orientacoes: List<String>.from(json['orientacoes'] as List),
        apoio: json['apoio'] as String?,
        aviso: json['aviso'] as String,
        criadoEm: DateTime.parse(json['criado_em'] as String).toLocal(),
      );
}

/// Item de GET /usuarios/{id}/avaliacoes.
class AvaliacaoResumo {
  final int id;
  final DateTime criadoEm;
  final String nivelRisco;
  final Probabilidades probabilidades;
  final double horasIaSemana;
  final int ansiedadeProvas;

  const AvaliacaoResumo({
    required this.id,
    required this.criadoEm,
    required this.nivelRisco,
    required this.probabilidades,
    required this.horasIaSemana,
    required this.ansiedadeProvas,
  });

  factory AvaliacaoResumo.fromJson(Map<String, dynamic> json) => AvaliacaoResumo(
        id: json['id'] as int,
        criadoEm: DateTime.parse(json['criado_em'] as String).toLocal(),
        nivelRisco: json['nivel_risco'] as String,
        probabilidades: Probabilidades.fromJson(json['probabilidades'] as Map<String, dynamic>),
        horasIaSemana: (json['horas_ia_semana'] as num).toDouble(),
        ansiedadeProvas: json['ansiedade_provas'] as int,
      );
}
