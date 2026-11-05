"""Gera as referências usadas nas dicas do painel do estudante.

Calcula, a partir da base de treino, a média de cada resposta numérica por nível de risco e o
desvio padrão geral, e salva em backend/app/referencias_base.json. A API compara a média do
estudante com a dos estudantes de risco baixo: assim as dicas vêm dos dados, não de números soltos.

Uso (na pasta ml/):
    python src/gerar_referencias.py
"""

import json
from pathlib import Path

import pandas as pd

from preparar_base import ORIGEM, tratar_base
from variaveis import ALVO, BINARIAS, NUMERICAS

DESTINO = Path(__file__).resolve().parents[2] / "backend" / "app" / "referencias_base.json"


def calcular_referencias(bruta: pd.DataFrame) -> dict:
    base = tratar_base(bruta)
    colunas = NUMERICAS + BINARIAS
    medias = base.groupby(ALVO)[colunas].mean()

    def arredondar(serie: pd.Series) -> dict[str, float]:
        return {coluna: round(float(valor), 2) for coluna, valor in serie.items()}

    return {
        "fonte": "Média por nível de risco na base de treino (Kaggle, 50 mil registros, provavelmente sintética).",
        "media_risco_baixo": arredondar(medias.loc["baixo"]),
        "media_risco_alto": arredondar(medias.loc["alto"]),
        "desvio": arredondar(base[colunas].std()),
    }


def main() -> None:
    referencias = calcular_referencias(pd.read_csv(ORIGEM))
    DESTINO.write_text(json.dumps(referencias, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Referências salvas em {DESTINO}")


if __name__ == "__main__":
    main()
