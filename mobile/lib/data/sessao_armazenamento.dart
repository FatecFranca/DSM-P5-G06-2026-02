import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/sessao.dart';

/// Guarda a sessão (token de login) no armazenamento seguro do sistema
/// (Keystore no Android, Keychain no iOS), nunca nas preferências comuns.
class SessaoArmazenamento {
  SessaoArmazenamento([FlutterSecureStorage? armazenamento])
      : _armazenamento = armazenamento ?? const FlutterSecureStorage();

  final FlutterSecureStorage _armazenamento;
  static const _chave = 'sessao';

  /// Sessão salva e ainda válida, ou null. Uma sessão vencida ou corrompida é descartada.
  Future<Sessao?> carregar({DateTime? agora}) async {
    final String? texto;
    try {
      texto = await _armazenamento.read(key: _chave);
    } on PlatformException {
      return null; // armazenamento seguro indisponível no aparelho: segue sem login
    }
    if (texto == null) return null;
    try {
      final sessao = Sessao.fromJson(jsonDecode(texto) as Map<String, dynamic>);
      if (!sessao.expiradaEm(agora ?? DateTime.now())) return sessao;
    } on FormatException {
      // conteúdo inválido: tratado como "sem sessão"
    } on TypeError {
      // campo faltando ou de outro tipo: idem
    }
    await apagar();
    return null;
  }

  Future<void> salvar(Sessao sessao) =>
      _armazenamento.write(key: _chave, value: jsonEncode(sessao.toJson()));

  Future<void> apagar() => _armazenamento.delete(key: _chave);
}
