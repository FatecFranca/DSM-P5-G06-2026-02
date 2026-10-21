"""Definição única das variáveis do modelo Equilibra.

A base original (Kaggle "Impact of AI on Students") usa nomes e categorias em
inglês. Aqui fica o mapeamento para os nomes em português usados pelo modelo,
pela API e pelo app, para que as três partes falem a mesma "língua".
"""

ALVO_ORIGINAL = "Burnout_Risk_Level"
ALVO = "nivel_risco"

# Colunas removidas e o motivo (documentado no relatório).
COLUNAS_REMOVIDAS = {
    "Student_ID": "identificador, sem valor preditivo",
    "Post_Semester_GPA": "medida no fim do semestre: vazamento de dados",
    "Skill_Retention_Score": "medida no fim do semestre: vazamento de dados",
}

# nome original -> nome em português
RENOMEAR = {
    "Major_Category": "area_curso",
    "Year_of_Study": "ano_curso",
    "Pre_Semester_GPA": "nota_semestre_anterior",
    "Weekly_GenAI_Hours": "horas_ia_semana",
    "Primary_Use_Case": "uso_principal_ia",
    "Prompt_Engineering_Skill": "nivel_prompt",
    "Tool_Diversity": "qtd_ferramentas_ia",
    "Paid_Subscription": "assinatura_paga",
    "Traditional_Study_Hours": "horas_estudo_semana",
    "Perceived_AI_Dependency": "dependencia_ia",
    "Institutional_Policy": "politica_instituicao",
    "Anxiety_Level_During_Exams": "ansiedade_provas",
    ALVO_ORIGINAL: ALVO,
}

# valores das categorias: original -> português
CATEGORIAS = {
    "area_curso": {
        "STEM": "exatas",
        "Business": "negocios",
        "Humanities": "humanas",
        "Medical": "saude",
        "Arts": "artes",
    },
    "ano_curso": {
        "Freshman": "primeiro_ano",
        "Sophomore": "segundo_ano",
        "Junior": "terceiro_ano",
        "Senior": "quarto_ano",
        "Graduate": "pos_graduacao",
    },
    "uso_principal_ia": {
        "Debugging/Troubleshooting": "depurar_codigo",
        "Copywriting/Drafting": "redigir_textos",
        "Ideation": "gerar_ideias",
        "Summarizing_Reading": "resumir_leituras",
        "Direct_Answer_Generation": "respostas_prontas",
    },
    "nivel_prompt": {
        "Beginner": "iniciante",
        "Intermediate": "intermediario",
        "Advanced": "avancado",
    },
    "politica_instituicao": {
        "Strict_Ban": "proibido",
        "Allowed_With_Citation": "permitido_com_citacao",
        "Actively_Encouraged": "incentivado",
    },
    ALVO: {"Low": "baixo", "Medium": "medio", "High": "alto"},
}

# A nota original vai de 0 a 4 (GPA americano). Convertemos para 0 a 10.
FATOR_NOTA = 2.5

NUMERICAS = [
    "nota_semestre_anterior",
    "horas_ia_semana",
    "horas_estudo_semana",
    "qtd_ferramentas_ia",
    "dependencia_ia",
    "ansiedade_provas",
]
BINARIAS = ["assinatura_paga"]
CATEGORICAS = [
    "area_curso",
    "ano_curso",
    "uso_principal_ia",
    "nivel_prompt",
    "politica_instituicao",
]
ENTRADAS = NUMERICAS + BINARIAS + CATEGORICAS
CLASSES = ["baixo", "medio", "alto"]
