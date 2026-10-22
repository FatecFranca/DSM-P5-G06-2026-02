import 'package:equilibra/data/api_demo.dart';
import 'package:equilibra/data/models/questionario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ApiDemo api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = ApiDemo(await SharedPreferences.getInstance());
  });

  test('Modo demo classifica, salva no histórico e apaga', () async {
    final tranquilo = Questionario()
      ..ansiedadeProvas = 1
      ..dependenciaIa = 1
      ..horasIaSemana = 0
      ..horasEstudoSemana = 20
      ..notaSemestreAnterior = 10;
    final ansioso = Questionario()
      ..ansiedadeProvas = 10
      ..dependenciaIa = 10
      ..horasIaSemana = 50
      ..horasEstudoSemana = 0
      ..notaSemestreAnterior = 3;

    final r1 = await api.prever('x', tranquilo);
    final r2 = await api.prever('x', ansioso);
    expect(r1.nivelRisco, 'baixo');
    expect(r1.apoio, isNull);
    expect(r2.nivelRisco, 'alto');
    expect(r2.apoio, contains('188'));

    final p = r2.probabilidades;
    expect(p.baixo + p.medio + p.alto, closeTo(1, 1e-3));

    final historico = await api.historico('x');
    expect(historico.map((a) => a.nivelRisco), ['alto', 'baixo']); // mais recente primeiro

    await api.apagarDados('x');
    expect(await api.historico('x'), isEmpty);
  });

  test('Modo demo simula cadastro e login mantendo o id do aparelho', () async {
    final cadastro = await api.cadastrar(usuarioId: 'anon-1', email: 'Ana@Exemplo.com', senha: '12345678');
    expect(cadastro.usuarioId, 'anon-1');
    expect(cadastro.email, 'ana@exemplo.com');
    expect(cadastro.expirada, isFalse);

    final login = await api.entrar(email: 'ana@exemplo.com', senha: '12345678', usuarioIdAnonimo: 'anon-1');
    expect(login.usuarioId, 'anon-1');
  });
}
