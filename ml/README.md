# Base de dados e modelo

## Origem

[Impact of AI on Students](https://www.kaggle.com/datasets/laveshjadon/ai-impact-on-students) (Kaggle), licença CC0 (domínio público). São 50.000 registros e 16 colunas, sem valores ausentes e sem linhas duplicadas.

O autor não descreve como os dados foram coletados, e por isso tratamos a base como provavelmente sintética. Essa é uma limitação do projeto: os resultados ilustram o método e não valem como estudo sobre estudantes reais.

## Etapas

1. `src/preparar_base.py`: confere a qualidade, remove colunas, traduz nomes e categorias e gera `data/processed/base_tratada.csv` e `reports/qualidade_base.json`.
2. `src/treinar_modelo.py`: compara 3 algoritmos, escolhe um, avalia, salva `models/modelo_burnout.joblib` e gera `reports/metricas_modelo.json`.

As duas usam `src/variaveis.py`, que é a definição única das variáveis. API e app usam exatamente os mesmos nomes.

## Decisões de preparo

| Decisão | Motivo |
| --- | --- |
| Remover `Student_ID` | Identificador, sem valor preditivo |
| Remover `Post_Semester_GPA` e `Skill_Retention_Score` | São medidas no fim do semestre. Usá-las seria vazamento de dados, e o estudante não sabe esses valores quando responde ao app |
| Traduzir nomes e categorias para o português | O app e a API usam os mesmos valores do modelo, sem tradução no meio do caminho |
| Converter a nota de 0–4 (GPA) para 0–10 | É a escala que o estudante brasileiro conhece |
| Não fazer imputação nem tratar outliers | A base não tem ausentes, e as faixas de valores são plausíveis |

## Dicionário de dados (base tratada)

| Coluna | Tipo | Valores |
| --- | --- | --- |
| `area_curso` | categórica | exatas, negocios, humanas, saude, artes |
| `ano_curso` | categórica | primeiro_ano, segundo_ano, terceiro_ano, quarto_ano, pos_graduacao |
| `nota_semestre_anterior` | numérica | 0 a 10 |
| `horas_ia_semana` | numérica | 0 a 40 na base |
| `horas_estudo_semana` | numérica | 1 a 36 na base |
| `qtd_ferramentas_ia` | inteira | 1 a 5 na base |
| `dependencia_ia` | inteira | 1 a 10 |
| `ansiedade_provas` | inteira | 1 a 10 |
| `assinatura_paga` | binária | 0 ou 1 |
| `uso_principal_ia` | categórica | depurar_codigo, redigir_textos, gerar_ideias, resumir_leituras, respostas_prontas |
| `nivel_prompt` | categórica | iniciante, intermediario, avancado |
| `politica_instituicao` | categórica | proibido, permitido_com_citacao, incentivado |
| **`nivel_risco`** (alvo) | categórica | baixo (16.369), medio (21.144), alto (12.487) |

## Resultados

A base foi dividida em 80% para treino e 20% para teste (estratificado, semente 42). No treino, cada algoritmo passou por validação cruzada estratificada de 5 partições, e todos usaram pesos balanceados entre as classes.

| Algoritmo | Acurácia (VC) | F1 macro (VC) | Recall risco alto (VC) |
| --- | --- | --- | --- |
| **Gradient boosting** (escolhido) | 51,6% | **0,521** | 61,0% |
| Random forest | 51,5% | 0,518 | 62,8% |
| Regressão logística | 51,4% | 0,517 | 63,1% |

O critério de escolha foi o maior F1 macro. No conjunto de teste, o modelo escolhido obteve:

- acurácia de **51,9%**, contra 42,3% de quem sempre responde a classe mais comum;
- F1 macro de 0,524;
- recall de 60% no risco alto, 66% no baixo e 36% no médio.

Matriz de confusão no teste (linhas = real, colunas = previsto):

| | baixo | medio | alto |
| --- | --- | --- | --- |
| **baixo** | 2156 | 890 | 228 |
| **medio** | 1738 | 1523 | 968 |
| **alto** | 374 | 616 | 1507 |

**Leitura:** os três algoritmos empatam na prática, o que indica que o limite está na base e não no algoritmo. O risco médio é o mais confundido, porque fica entre os outros dois. Erros extremos (alto previsto como baixo) são poucos. As variáveis mais importantes são horas de IA por semana, nota anterior, horas de estudo sem IA, ansiedade e dependência de IA.
