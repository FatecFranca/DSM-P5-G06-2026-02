/// Validações dos formulários de conta.
/// Cada função devolve a mensagem de erro para mostrar no campo, ou null quando está tudo certo.
class Validacoes {
  static final _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const tamanhoMinimoSenha = 8;
  static const tamanhoMaximoSenha = 128; // mesmo limite da API

  static String? email(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe seu e-mail.';
    if (!_formatoEmail.hasMatch(texto)) return 'E-mail inválido.';
    return null;
  }

  /// Senha nova (cadastro): exige o tamanho mínimo.
  static String? senhaNova(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Crie uma senha.';
    if (texto.length < tamanhoMinimoSenha) {
      return 'A senha precisa ter pelo menos $tamanhoMinimoSenha caracteres.';
    }
    if (texto.length > tamanhoMaximoSenha) {
      return 'A senha pode ter no máximo $tamanhoMaximoSenha caracteres.';
    }
    return null;
  }

  /// Senha de login: só não pode estar vazia (quem confere é a API).
  static String? senhaLogin(String? valor) => (valor ?? '').isEmpty ? 'Informe sua senha.' : null;

  static String? confirmacao(String? valor, String senha) =>
      valor == senha ? null : 'As senhas não são iguais.';
}
