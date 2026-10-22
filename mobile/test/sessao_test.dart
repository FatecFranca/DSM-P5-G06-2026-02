import 'dart:convert';

import 'package:equilibra/data/models/sessao.dart';
import 'package:equilibra/data/sessao_armazenamento.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final _expira = DateTime.utc(2026, 11, 1, 12);

Sessao _sessao() => Sessao(
      token: 'abc.def.ghi',
      usuarioId: '7f1c9a52-0000-4000-8000-000000000001',
      email: 'ana@exemplo.com',
      expiraEm: _expira,
    );

void main() {
  group('Sessao', () {
    test('lê a resposta de /auth/login (campos extras são ignorados)', () {
      final s = Sessao.fromJson({
        'token': 'abc.def.ghi',
        'tipo': 'bearer',
        'expira_em': '2026-11-01T12:00:00.123456Z',
        'usuario_id': '7f1c9a52-0000-4000-8000-000000000001',
        'email': 'ana@exemplo.com',
      });
      expect(s.email, 'ana@exemplo.com');
      expect(s.expiraEm.isUtc, isTrue);
    });

    test('ida e volta pelo JSON preserva os dados', () {
      final volta = Sessao.fromJson(_sessao().toJson());
      expect(volta.token, 'abc.def.ghi');
      expect(volta.expiraEm, _expira);
    });

    test('é considerada vencida um minuto antes do horário real', () {
      final s = _sessao();
      expect(s.expiradaEm(_expira.subtract(const Duration(minutes: 2))), isFalse);
      expect(s.expiradaEm(_expira.subtract(const Duration(seconds: 30))), isTrue);
      expect(s.expiradaEm(_expira.add(const Duration(days: 1))), isTrue);
    });
  });

  group('SessaoArmazenamento', () {
    final antes = _expira.subtract(const Duration(days: 1));

    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('salva e carrega a sessão', () async {
      final armazenamento = SessaoArmazenamento();
      await armazenamento.salvar(_sessao());
      final carregada = await armazenamento.carregar(agora: antes);
      expect(carregada?.email, 'ana@exemplo.com');
    });

    test('sessão vencida é descartada', () async {
      final armazenamento = SessaoArmazenamento();
      await armazenamento.salvar(_sessao());
      expect(await armazenamento.carregar(agora: _expira.add(const Duration(hours: 1))), isNull);
      expect(await armazenamento.carregar(agora: antes), isNull); // foi apagada
    });

    test('conteúdo corrompido é descartado sem quebrar o app', () async {
      FlutterSecureStorage.setMockInitialValues({'sessao': 'isto não é json'});
      expect(await SessaoArmazenamento().carregar(agora: antes), isNull);

      FlutterSecureStorage.setMockInitialValues({'sessao': jsonEncode({'token': 1})});
      expect(await SessaoArmazenamento().carregar(agora: antes), isNull);
    });

    test('apagar remove a sessão', () async {
      final armazenamento = SessaoArmazenamento();
      await armazenamento.salvar(_sessao());
      await armazenamento.apagar();
      expect(await armazenamento.carregar(agora: antes), isNull);
    });
  });
}
