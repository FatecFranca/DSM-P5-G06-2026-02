import 'package:equilibra/data/models/questionario.dart';
import 'package:equilibra/data/models/resultado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Questionario gera o JSON com os nomes esperados pela API', () {
    final json = Questionario().toJson();
    expect(json.keys, containsAll([
      'area_curso', 'ano_curso', 'nota_semestre_anterior', 'horas_ia_semana',
      'horas_estudo_semana', 'qtd_ferramentas_ia', 'dependencia_ia', 'ansiedade_provas',
      'assinatura_paga', 'uso_principal_ia', 'nivel_prompt', 'politica_instituicao',
    ]));
    expect(json.length, 12);
  });

  test('Resultado lê a resposta de POST /predicoes', () {
    final r = Resultado.fromJson({
      'avaliacao_id': 1,
      'nivel_risco': 'alto',
      'probabilidades': {'baixo': 0.08, 'medio': 0.28, 'alto': 0.64},
      'orientacoes': ['Faça pausas'],
      'apoio': 'CVV 188',
      'aviso': 'Não é diagnóstico',
      'versao_modelo': 'gradient_boosting-20261019',
      'criado_em': '2026-10-19T16:47:36-03:00',
    });
    expect(r.nivelRisco, 'alto');
    expect(r.probabilidades.alto, closeTo(0.64, 1e-9));
    expect(r.apoio, isNotNull);
  });
}
