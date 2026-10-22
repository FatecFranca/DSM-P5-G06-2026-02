/// Sessão de quem entrou com e-mail e senha. Vem de POST /auth/login ou /auth/cadastro.
class Sessao {
  final String token;
  final String usuarioId;
  final String email;
  final DateTime expiraEm;

  const Sessao({
    required this.token,
    required this.usuarioId,
    required this.email,
    required this.expiraEm,
  });

  /// Considera vencida um pouco antes do horário real, para não usar um token no limite.
  bool expiradaEm(DateTime agora) => !agora.isBefore(expiraEm.subtract(const Duration(minutes: 1)));

  bool get expirada => expiradaEm(DateTime.now());

  /// Lê tanto a resposta da API quanto o que foi salvo no aparelho (mesmos nomes).
  factory Sessao.fromJson(Map<String, dynamic> json) => Sessao(
        token: json['token'] as String,
        usuarioId: json['usuario_id'] as String,
        email: json['email'] as String,
        expiraEm: DateTime.parse(json['expira_em'] as String),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'usuario_id': usuarioId,
        'email': email,
        'expira_em': expiraEm.toUtc().toIso8601String(),
      };
}
