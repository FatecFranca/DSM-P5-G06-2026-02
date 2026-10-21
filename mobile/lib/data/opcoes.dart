/// Opções das perguntas: valor enviado à API -> texto mostrado na tela.
/// Os valores são exatamente os aceitos pela API e usados pelo modelo.
class Opcoes {
  static const areaCurso = {
    'exatas': 'Exatas e tecnologia',
    'negocios': 'Negócios e gestão',
    'humanas': 'Humanas',
    'saude': 'Saúde',
    'artes': 'Artes',
  };

  static const anoCurso = {
    'primeiro_ano': '1º ano',
    'segundo_ano': '2º ano',
    'terceiro_ano': '3º ano',
    'quarto_ano': '4º ano ou mais',
    'pos_graduacao': 'Pós-graduação',
  };

  static const usoPrincipalIa = {
    'depurar_codigo': 'Corrigir código',
    'redigir_textos': 'Escrever textos',
    'gerar_ideias': 'Gerar ideias',
    'resumir_leituras': 'Resumir leituras',
    'respostas_prontas': 'Obter respostas prontas',
  };

  static const nivelPrompt = {
    'iniciante': 'Iniciante',
    'intermediario': 'Intermediário',
    'avancado': 'Avançado',
  };

  static const politicaInstituicao = {
    'proibido': 'Proíbe o uso de IA',
    'permitido_com_citacao': 'Permite, com citação',
    'incentivado': 'Incentiva o uso',
  };
}
