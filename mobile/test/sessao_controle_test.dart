import 'package:equilibra/data/api_cliente.dart';
import 'package:equilibra/state/provedores.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/falsos.dart';

void main() {
  const anonimo = {'usuario_id': 'anon-1', 'consentiu': true};

  test('cadastro usa o id anônimo do aparelho e guarda a sessão', () async {
    final api = ApiFalsa();
    final c = await criarContainer(api, prefs: anonimo);

    await c.read(sessaoProvider.notifier).cadastrar(email: 'ana@exemplo.com', senha: '12345678');

    final sessao = c.read(sessaoProvider);
    expect(sessao?.usuarioId, 'anon-1'); // a conta é o próprio usuário anônimo
    expect(c.read(armazenamentoProvider).emailDaConta, 'ana@exemplo.com');
    expect((await c.read(sessaoArmazenamentoProvider).carregar())?.token, 'tok-anon-1');
  });

  test('login une o histórico anônimo e o aparelho passa a usar o id da conta', () async {
    final api = ApiFalsa();
    final c = await criarContainer(api, prefs: anonimo);

    await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: '12345678');

    expect(api.ultimoIdAnonimo, 'anon-1');
    expect(c.read(armazenamentoProvider).usuarioId, 'id-da-conta');
    expect(c.read(sessaoProvider)?.email, 'ana@exemplo.com');
  });

  test('erro da API não muda nada no aparelho', () async {
    final api = ApiFalsa()..erro = ErroApi('E-mail ou senha incorretos.');
    final c = await criarContainer(api, prefs: anonimo);

    await expectLater(
      c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: 'errada'),
      throwsA(isA<ErroApi>()),
    );
    expect(c.read(sessaoProvider), isNull);
    expect(c.read(armazenamentoProvider).usuarioId, 'anon-1');
    expect(c.read(armazenamentoProvider).emailDaConta, isNull);
  });

  test('sair apaga a sessão e volta a pedir o termo', () async {
    final api = ApiFalsa();
    final c = await criarContainer(api, prefs: anonimo);
    await c.read(sessaoProvider.notifier).entrar(email: 'ana@exemplo.com', senha: '12345678');

    await c.read(sessaoProvider.notifier).sair();

    final local = c.read(armazenamentoProvider);
    expect(c.read(sessaoProvider), isNull);
    expect(await c.read(sessaoArmazenamentoProvider).carregar(), isNull);
    expect(local.consentiu, isFalse);
    expect(local.emailDaConta, isNull);
    expect(local.usuarioId, isNot('id-da-conta')); // novo id anônimo
  });
}
