import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/data/models/painel.dart';
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

  /// Erro devolvido por cadastrar/entrar.
  ErroApi? erro;

  /// Erro devolvido por prever, historico e painel (ex.: ErroCadastroAusente).
  ErroApi? erroDados;

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
  Future<List<AvaliacaoResumo>> historico(String usuarioId) async {
    if (erroDados != null) throw erroDados!;
    return [];
  }

  /// O que painel() devolve; sem definir, um painel vazio.
  Painel painelDevolvido = const Painel(totalAvaliacoes: 0, aviso: 'Não é diagnóstico');

  /// Falha interna (não é ErroApi) ao carregar o painel.
  Object? painelErroInterno;

  @override
  Future<Painel> painel(String usuarioId) async {
    chamadas.add('painel');
    if (erroDados != null) throw erroDados!;
    if (painelErroInterno != null) throw painelErroInterno!;
    return painelDevolvido;
  }

  @override
  Future<Resultado> prever(String usuarioId, Questionario respostas) async {
    chamadas.add('prever');
    if (erroDados != null) throw erroDados!;
    throw UnimplementedError('resultado não usado nestes testes');
  }
}

/// Container do Riverpod com armazenamentos em memória e a API falsa no lugar das duas APIs.
/// Atenção: trocar as APIs inteiras esconde problemas de ligação entre provedores (como um ciclo);
/// para isso use [criarContainerComRede], que mantém os provedores reais.
Future<ProviderContainer> criarContainer(
  ApiFalsa api, {
  Map<String, Object> prefs = const {},
  Sessao? sessao,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    apiProvider.overrideWithValue(api),
    apiPublicaProvider.overrideWithValue(api),
    sessaoInicialProvider.overrideWithValue(sessao),
  ]);
  return container;
}

/// Responde as chamadas do Dio sem rede e guarda o que foi enviado.
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.responder);

  final ResponseBody Function(RequestOptions pedido) responder;
  final pedidos = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pedidos.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody resposta(int status, Object corpo, {Map<String, List<String>> cabecalhos = const {}}) =>
    ResponseBody.fromString(jsonEncode(corpo), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...cabecalhos,
    });

/// Container com os provedores REAIS do app (como no celular); só a rede é falsa.
Future<ProviderContainer> criarContainerComRede(
  AdaptadorFalso adaptador, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({});
  final dio = Dio(BaseOptions(baseUrl: 'http://api'))..httpClientAdapter = adaptador;
  return ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    dioProvider.overrideWithValue(dio),
  ]);
}
