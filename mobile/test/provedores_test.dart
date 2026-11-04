// Testes da ligação REAL entre os provedores (só a rede é falsa).
//
// Regressão: criar conta dava "CircularDependencyError" com a API real, porque a sessão usava a API
// que depende da própria sessão. Os outros testes trocam as APIs inteiras e não pegavam isso.
import 'package:dio/dio.dart';
import 'package:equilibra/core/mensagens.dart';
import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/falsos.dart';

const _sessaoJson = {
  'token': 'token-real',
  'tipo': 'bearer',
  'expira_em': '2099-01-01T00:00:00Z',
  'usuario_id': 'id-da-conta',
  'email': 'ana@exemplo.com',
};

/// Responde como a API: cadastro/login devolvem a sessão; histórico devolve lista vazia.
ResponseBody responderComoApi(RequestOptions pedido) {
  if (pedido.path.startsWith('/auth/')) return resposta(200, _sessaoJson);
  return resposta(200, []);
}

void main() {
  const anonimo = {'usuario_id': 'anon-1', 'consentiu': true};

  test('criar conta com os provedores reais não cria ciclo e usa o token depois', () async {
    final rede = AdaptadorFalso(responderComoApi);
    final c = await criarContainerComRede(rede, prefs: anonimo);
    addTearDown(c.dispose);
    c.read(apiProvider); // como no app: a tela inicial já usou a API antes do cadastro

    await c.read(sessaoProvider.notifier).cadastrar(email: 'ana@exemplo.com', senha: '12345678');

    expect(c.read(sessaoProvider)?.token, 'token-real');
    final cadastro = rede.pedidos.single;
    expect(cadastro.path, '/auth/cadastro');
    expect(cadastro.headers.containsKey('Authorization'), isFalse); // cadastro não leva token

    await c.read(apiProvider).historico('id-da-conta');
    expect(rede.pedidos.last.headers['Authorization'], 'Bearer token-real'); // API recriada com o token
  });

  test('entrar com os provedores reais também funciona', () async {
    final rede = AdaptadorFalso(responderComoApi);
    final c = await criarContainerComRede(rede, prefs: anonimo);
    addTearDown(c.dispose);
    c.read(apiProvider);

    await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: '12345678');

    expect(c.read(sessaoProvider)?.usuarioId, 'id-da-conta');
    expect(rede.pedidos.single.data['usuario_id_anonimo'], 'anon-1');
  });

  group('mensagemDeErro', () {
    test('erro da API mostra a mensagem dela', () {
      expect(mensagemDeErro(ErroApi('E-mail ou senha incorretos.')), 'E-mail ou senha incorretos.');
    });

    test('erro interno nunca aparece cru para o usuário', () {
      final texto = mensagemDeErro(StateError('ciclo entre provedores'));
      expect(texto, 'Algo deu errado. Tente de novo.');
      expect(texto, isNot(contains('Instance of')));
    });
  });
}
