import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/data/models/questionario.dart';
import 'package:equilibra/data/models/resultado.dart';
import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API falsa para testes: registra as chamadas e devolve sessões prontas.
class ApiFalsa implements ApiCliente {
  final chamadas = <String>[];
  String? ultimoIdAnonimo;
  ErroApi? erro;

  Sessao _sessao(String usuarioId, String email) => Sessao(
        token: 'tok-$usuarioId',
        usuarioId: usuarioId,
        email: email,
        expiraEm: DateTime.now().add(const Duration(days: 7)),
      );

  @override
  Future<Sessao> cadastrar({required String usuarioId, required String email, required String senha}) async {
    chamadas.add('cadastrar');
    if (erro != null) throw erro!;
    return _sessao(usuarioId, email);
  }

  @override
  Future<Sessao> entrar({required String email, required String senha, String? usuarioIdAnonimo}) async {
    chamadas.add('entrar');
    ultimoIdAnonimo = usuarioIdAnonimo;
    if (erro != null) throw erro!;
    return _sessao('id-da-conta', email);
  }

  @override
  Future<void> registrarUsuario(String usuarioId) async => chamadas.add('registrarUsuario');

  @override
  Future<void> apagarDados(String usuarioId) async => chamadas.add('apagarDados');

  @override
  Future<List<AvaliacaoResumo>> historico(String usuarioId) async => [];

  @override
  Future<Resultado> prever(String usuarioId, Questionario respostas) =>
      throw UnimplementedError('não usado nestes testes');
}

/// Container do Riverpod com armazenamentos em memória e a API falsa.
Future<ProviderContainer> criarContainer(ApiFalsa api, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    apiProvider.overrideWithValue(api),
  ]);
  return container;
}
