import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Guarda no aparelho só o necessário: o id do usuário, se o termo foi aceito e,
/// quando há conta, o e-mail dela (para avisar que a sessão expirou).
/// O token de login fica à parte, no armazenamento seguro (ver SessaoArmazenamento).
class ArmazenamentoLocal {
  ArmazenamentoLocal(this._prefs);

  final SharedPreferences _prefs;
  static const _chaveId = 'usuario_id';
  static const _chaveConsentimento = 'consentiu';
  static const _chaveEmailConta = 'email_conta';

  bool get consentiu => _prefs.getBool(_chaveConsentimento) ?? false;

  /// Id do usuário neste aparelho: anônimo até entrar numa conta. Criado na primeira vez em que é pedido.
  String get usuarioId {
    final existente = _prefs.getString(_chaveId);
    if (existente != null) return existente;
    final novo = const Uuid().v4();
    _prefs.setString(_chaveId, novo);
    return novo;
  }

  /// E-mail da conta ligada a este aparelho (null para usuário anônimo).
  String? get emailDaConta => _prefs.getString(_chaveEmailConta);

  Future<void> registrarConsentimento() => _prefs.setBool(_chaveConsentimento, true);

  /// Depois do login, o aparelho passa a usar o id da conta.
  Future<void> vincularConta({required String usuarioId, required String email}) async {
    await _prefs.setString(_chaveId, usuarioId);
    await _prefs.setString(_chaveEmailConta, email);
  }

  /// Usado ao sair da conta ou apagar os dados: o próximo id será outro e o termo é pedido de novo.
  Future<void> limpar() async {
    await _prefs.remove(_chaveId);
    await _prefs.remove(_chaveConsentimento);
    await _prefs.remove(_chaveEmailConta);
  }
}
