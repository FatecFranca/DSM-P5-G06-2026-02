"""Etapa 1: preparar a base de dados.

Lê a base original do Kaggle, confere a qualidade, remove colunas que não podem
ser usadas, traduz nomes e categorias e salva a base tratada.

Uso (na pasta ml/):
    python src/preparar_base.py
"""

import json
from pathlib import Path

import pandas as pd

from variaveis import (
    ALVO,
    CATEGORIAS,
    COLUNAS_REMOVIDAS,
    ENTRADAS,
    FATOR_NOTA,
    RENOMEAR,
)

RAIZ = Path(__file__).resolve().parents[1]
ORIGEM = RAIZ / "data" / "raw" / "ai_student_impact_dataset.csv"
DESTINO = RAIZ / "data" / "processed" / "base_tratada.csv"
RELATORIO = RAIZ / "reports" / "qualidade_base.json"


def main() -> None:
    bruta = pd.read_csv(ORIGEM)

    qualidade = {
        "linhas": int(len(bruta)),
        "colunas": int(bruta.shape[1]),
        "ausentes": int(bruta.isna().sum().sum()),
        "linhas_duplicadas": int(bruta.duplicated().sum()),
        "ids_duplicados": int(bruta["Student_ID"].duplicated().sum()),
    }

    base = bruta.drop(columns=list(COLUNAS_REMOVIDAS))
    base = base.rename(columns=RENOMEAR)

    for coluna, traducao in CATEGORIAS.items():
        desconhecidos = set(base[coluna].unique()) - set(traducao)
        if desconhecidos:
            raise ValueError(f"Valores inesperados em {coluna}: {desconhecidos}")
        base[coluna] = base[coluna].map(traducao)

    base["nota_semestre_anterior"] = (base["nota_semestre_anterior"] * FATOR_NOTA).round(2)
    base["assinatura_paga"] = base["assinatura_paga"].astype(int)
    base = base[ENTRADAS + [ALVO]]

    qualidade["distribuicao_alvo"] = base[ALVO].value_counts().to_dict()
    qualidade["faixas_numericas"] = {
        c: [float(base[c].min()), float(base[c].max())]
        for c in base.select_dtypes("number").columns
    }
    qualidade["colunas_removidas"] = COLUNAS_REMOVIDAS

    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    RELATORIO.parent.mkdir(parents=True, exist_ok=True)
    base.to_csv(DESTINO, index=False)
    RELATORIO.write_text(json.dumps(qualidade, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"Base tratada: {len(base)} linhas, {base.shape[1]} colunas -> {DESTINO}")
    print(json.dumps(qualidade["distribuicao_alvo"], ensure_ascii=False))


if __name__ == "__main__":
    main()
