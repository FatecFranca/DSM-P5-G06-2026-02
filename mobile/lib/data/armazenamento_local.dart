import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Guarda no aparelho só o necessário: o id anônimo e se o termo foi aceito.
class ArmazenamentoLocal {
  ArmazenamentoLocal(this._prefs);

  final SharedPreferences _prefs;
  static const _chaveId = 'usuario_id';
  static const _chaveConsentimento = 'consentiu';

  bool get consentiu => _prefs.getBool(_chaveConsentimento) ?? false;

  /// Id anônimo do aparelho. Criado na primeira vez em que é pedido.
  String get usuarioId {
    final existente = _prefs.getString(_chaveId);
    if (existente != null) return existente;
    final novo = const Uuid().v4();
    _prefs.setString(_chaveId, novo);
    return novo;
  }

  Future<void> registrarConsentimento() => _prefs.setBool(_chaveConsentimento, true);

  /// Usado quando o usuário apaga os dados: o próximo id será outro.
  Future<void> limpar() async {
    await _prefs.remove(_chaveId);
    await _prefs.remove(_chaveConsentimento);
  }
}
