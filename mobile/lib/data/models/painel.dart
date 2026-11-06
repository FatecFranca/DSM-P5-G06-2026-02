import 'resultado.dart';

/// Dica personalizada do painel. [tipo]: 'melhorar' ou 'manter'.
class DicaPainel {
  final String titulo;
  final String texto;
  final String tipo;

  const DicaPainel({required this.titulo, required this.texto, required this.tipo});

  bool get ehParaManter => tipo == 'manter';

  factory DicaPainel.fromJson(Map<String, dynamic> json) => DicaPainel(
        titulo: json['titulo'] as String,
        texto: json['texto'] as String,
        tipo: json['tipo'] as String,
      );
}

/// Resposta de GET /usuarios/{id}/painel: média de todas as respostas e dicas.
class Painel {
  final int totalAvaliacoes;
  final DateTime? ultimaEm;
  final String? riscoAtual;

  /// 'melhorando', 'piorando', 'estavel' ou null (menos de duas avaliações).
  final String? tendencia;
  final Probabilidades? probabilidadesMedias;

  /// Média das respostas numéricas. assinatura_paga é a fração de vezes, de 0 a 1.
  final Map<String, double> medias;

  /// Resposta mais frequente das perguntas de escolha.
  final Map<String, String> maisComuns;

  /// Média dos estudantes de risco baixo na base de treino.
  final Map<String, double> referencias;
  final String notaReferencias;
  final List<DicaPainel> dicas;
  final String? apoio;
  final String aviso;

  const Painel({
    required this.totalAvaliacoes,
    this.ultimaEm,
    this.riscoAtual,
    this.tendencia,
    this.probabilidadesMedias,
    this.medias = const {},
    this.maisComuns = const {},
    this.referencias = const {},
    this.notaReferencias = '',
    this.dicas = const [],
    this.apoio,
    required this.aviso,
  });

  bool get vazio => totalAvaliacoes == 0;

  factory Painel.fromJson(Map<String, dynamic> json) {
    final ultimaEm = json['ultima_em'] as String?;
    final probabilidades = json['probabilidades_medias'] as Map<String, dynamic>?;
    return Painel(
      totalAvaliacoes: json['total_avaliacoes'] as int,
      ultimaEm: ultimaEm == null ? null : DateTime.parse(ultimaEm).toLocal(),
      riscoAtual: json['risco_atual'] as String?,
      tendencia: json['tendencia'] as String?,
      probabilidadesMedias: probabilidades == null ? null : Probabilidades.fromJson(probabilidades),
      medias: _numeros(json['medias']),
      maisComuns: Map<String, String>.from(json['mais_comuns'] as Map),
      referencias: _numeros(json['referencias_risco_baixo']),
      notaReferencias: json['nota_referencias'] as String,
      dicas: (json['dicas'] as List).map((d) => DicaPainel.fromJson(d as Map<String, dynamic>)).toList(),
      apoio: json['apoio'] as String?,
      aviso: json['aviso'] as String,
    );
  }

  static Map<String, double> _numeros(Object? valor) =>
      (valor as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
}
