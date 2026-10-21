/// Respostas do estudante. Mutável porque é preenchido aos poucos no formulário.
class Questionario {
  String areaCurso = 'exatas';
  String anoCurso = 'primeiro_ano';
  double notaSemestreAnterior = 7;
  double horasIaSemana = 5;
  double horasEstudoSemana = 10;
  int qtdFerramentasIa = 1;
  int dependenciaIa = 3;
  int ansiedadeProvas = 4;
  bool assinaturaPaga = false;
  String usoPrincipalIa = 'gerar_ideias';
  String nivelPrompt = 'iniciante';
  String politicaInstituicao = 'permitido_com_citacao';

  Map<String, dynamic> toJson() => {
        'area_curso': areaCurso,
        'ano_curso': anoCurso,
        'nota_semestre_anterior': notaSemestreAnterior,
        'horas_ia_semana': horasIaSemana,
        'horas_estudo_semana': horasEstudoSemana,
        'qtd_ferramentas_ia': qtdFerramentasIa,
        'dependencia_ia': dependenciaIa,
        'ansiedade_provas': ansiedadeProvas,
        'assinatura_paga': assinaturaPaga,
        'uso_principal_ia': usoPrincipalIa,
        'nivel_prompt': nivelPrompt,
        'politica_instituicao': politicaInstituicao,
      };
}
