import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equilibra/data/api_cliente.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _sessaoJson = {
  'token': 'tok',
  'tipo': 'bearer',
  'expira_em': '2026-11-01T12:00:00Z',
  'usuario_id': 'conta-1',
  'email': 'ana@exemplo.com',
};

(ApiCliente, AdaptadorFalso) criar(ResponseBody Function(RequestOptions) responder, {String? token}) {
  final adaptador = AdaptadorFalso(responder);
  final dio = Dio(BaseOptions(baseUrl: 'http://api'))..httpClientAdapter = adaptador;
  return (ApiCliente(dio: dio, token: token), adaptador);
}

void main() {
  group('token de login', () {
    test('vai no cabeçalho Authorization quando há sessão', () async {
      final (api, adaptador) = criar((_) => resposta(200, []), token: 'tok');
      await api.historico('u1');
      expect(adaptador.pedidos.single.headers['Authorization'], 'Bearer tok');
    });

    test('não é enviado para usuário anônimo', () async {
      final (api, adaptador) = criar((_) => resposta(200, []));
      await api.historico('u1');
      expect(adaptador.pedidos.single.headers.containsKey('Authorization'), isFalse);
    });

    test('vai também na exclusão dos dados', () async {
      final (api, adaptador) = criar((_) => resposta(204, {}), token: 'tok');
      await api.apagarDados('u1');
      expect(adaptador.pedidos.single.headers['Authorization'], 'Bearer tok');
    });
  });

  group('cadastro e login', () {
    test('cadastro envia o aceite do termo 2.0 e devolve a sessão', () async {
      final (api, adaptador) = criar((_) => resposta(201, _sessaoJson));
      final sessao = await api.cadastrar(usuarioId: 'anon-1', email: 'ana@exemplo.com', senha: '12345678');

      final corpo = adaptador.pedidos.single.data as Map<String, dynamic>;
      expect(adaptador.pedidos.single.path, '/auth/cadastro');
      expect(corpo, containsPair('versao_termo', '2.0'));
      expect(corpo, containsPair('consentimento', true));
      expect(corpo, containsPair('usuario_id', 'anon-1'));
      expect(sessao.token, 'tok');
    });

    test('login envia o id anônimo só quando existe', () async {
      final (api, adaptador) = criar((_) => resposta(200, _sessaoJson));
      await api.entrar(email: 'ana@exemplo.com', senha: 'x', usuarioIdAnonimo: 'anon-1');
      await api.entrar(email: 'ana@exemplo.com', senha: 'x');

      final com = adaptador.pedidos[0].data as Map<String, dynamic>;
      final sem = adaptador.pedidos[1].data as Map<String, dynamic>;
      expect(com['usuario_id_anonimo'], 'anon-1');
      expect(sem.containsKey('usuario_id_anonimo'), isFalse);
    });
  });

  group('tradução de erros', () {
    Future<ErroApi> erroDe(ResponseBody corpo) async {
      final (api, _) = criar((_) => corpo);
      try {
        await api.historico('u1');
      } on ErroApi catch (e) {
        return e;
      }
      fail('esperava ErroApi');
    }

    test('401 com WWW-Authenticate: Bearer é sessão expirada', () async {
      final e = await erroDe(resposta(401, {'detail': 'Sessão inválida ou expirada. Faça login de novo.'},
          cabecalhos: {'www-authenticate': ['Bearer']}));
      expect(e, isA<ErroSessao>());
      expect(e.mensagem, contains('Faça login'));
    });

    test('401 sem Bearer não é sessão (ex.: senha errada no login)', () async {
      final e = await erroDe(resposta(401, {'detail': 'E-mail ou senha incorretos.'}));
      expect(e, isNot(isA<ErroSessao>()));
      expect(e.mensagem, 'E-mail ou senha incorretos.');
    });

    test('403 pede para entrar de novo', () async {
      expect(await erroDe(resposta(403, {'detail': 'x'})), isA<ErroSessao>());
    });

    test('409 e 429 mostram a mensagem da API', () async {
      expect((await erroDe(resposta(409, {'detail': 'Este e-mail já está cadastrado. Faça login.'}))).mensagem,
          contains('já está cadastrado'));
      expect((await erroDe(resposta(429, {'detail': 'Muitas tentativas de login.'}))).mensagem,
          contains('Muitas tentativas'));
    });

    test('422 com lista de erros usa a mensagem do app', () async {
      final e = await erroDe(resposta(422, {'detail': [{'msg': 'erro'}]}));
      expect(e.mensagem, 'Alguma resposta está fora do esperado.');
    });

    test('sem resposta do servidor', () async {
      final (api, _) = criar((p) => throw DioException.connectionError(requestOptions: p, reason: 'offline'));
      await expectLater(api.historico('u1'), throwsA(predicate((e) => '$e'.contains('Sem conexão'))));
    });
  });
}
