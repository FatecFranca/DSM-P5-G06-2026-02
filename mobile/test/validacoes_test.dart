import 'package:equilibra/core/validacoes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('e-mail', () {
    expect(Validacoes.email(''), 'Informe seu e-mail.');
    expect(Validacoes.email('   '), 'Informe seu e-mail.');
    expect(Validacoes.email('ana'), 'E-mail inválido.');
    expect(Validacoes.email('ana@exemplo'), 'E-mail inválido.');
    expect(Validacoes.email('ana @exemplo.com'), 'E-mail inválido.');
    expect(Validacoes.email(' ana@exemplo.com '), isNull);
  });

  test('senha nova exige de 8 a 128 caracteres', () {
    expect(Validacoes.senhaNova(''), 'Crie uma senha.');
    expect(Validacoes.senhaNova('1234567'), contains('pelo menos 8'));
    expect(Validacoes.senhaNova('12345678'), isNull);
    expect(Validacoes.senhaNova('x' * 128), isNull);
    expect(Validacoes.senhaNova('x' * 129), contains('no máximo 128'));
  });

  test('senha de login só não pode estar vazia', () {
    expect(Validacoes.senhaLogin(''), 'Informe sua senha.');
    expect(Validacoes.senhaLogin('curta'), isNull);
  });

  test('confirmação de senha', () {
    expect(Validacoes.confirmacao('abc12345', 'abc12345'), isNull);
    expect(Validacoes.confirmacao('abc12346', 'abc12345'), 'As senhas não são iguais.');
  });
}
