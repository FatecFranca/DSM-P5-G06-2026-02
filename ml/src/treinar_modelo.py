"""Etapa 2: treinar e escolher o classificador de risco de burnout.

Compara três algoritmos com validação cruzada estratificada (5 partições),
escolhe o de maior F1 macro, avalia num conjunto de teste separado (20%) e
salva o modelo final, treinado com a base inteira, para a API usar.

Uso (na pasta ml/), depois de preparar_base.py:
    python src/treinar_modelo.py
"""

import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    make_scorer,
    recall_score,
)
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

from variaveis import ALVO, BINARIAS, CATEGORICAS, CLASSES, ENTRADAS, NUMERICAS

RAIZ = Path(__file__).resolve().parents[1]
BASE = RAIZ / "data" / "processed" / "base_tratada.csv"
MODELO = RAIZ / "models" / "modelo_burnout.joblib"
RELATORIO = RAIZ / "reports" / "metricas_modelo.json"
SEMENTE = 42


def preprocessador() -> ColumnTransformer:
    return ColumnTransformer(
        [
            ("num", StandardScaler(), NUMERICAS + BINARIAS),
            ("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAS),
        ]
    )


def candidatos() -> dict[str, Pipeline]:
    return {
        "regressao_logistica": Pipeline(
            [
                ("prep", preprocessador()),
                ("clf", LogisticRegression(max_iter=2000, class_weight="balanced")),
            ]
        ),
        "gradient_boosting": Pipeline(
            [
                ("prep", preprocessador()),
                (
                    "clf",
                    HistGradientBoostingClassifier(
                        max_iter=200, learning_rate=0.05, class_weight="balanced",
                        random_state=SEMENTE,
                    ),
                ),
            ]
        ),
        "random_forest": Pipeline(
            [
                ("prep", preprocessador()),
                (
                    "clf",
                    RandomForestClassifier(
                        n_estimators=200, min_samples_leaf=20, class_weight="balanced",
                        n_jobs=-1, random_state=SEMENTE,
                    ),
                ),
            ]
        ),
    }


def main() -> None:
    base = pd.read_csv(BASE)
    X, y = base[ENTRADAS], base[ALVO]
    X_treino, X_teste, y_treino, y_teste = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=SEMENTE
    )

    metricas_cv = {
        "acuracia": "accuracy",
        "f1_macro": "f1_macro",
        "recall_alto": make_scorer(recall_score, labels=["alto"], average="macro"),
    }
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEMENTE)

    comparacao = {}
    for nome, modelo in candidatos().items():
        r = cross_validate(modelo, X_treino, y_treino, cv=cv, scoring=metricas_cv, n_jobs=-1)
        comparacao[nome] = {
            m: {"media": round(float(np.mean(r[f"test_{m}"])), 4),
                "desvio": round(float(np.std(r[f"test_{m}"])), 4)}
            for m in metricas_cv
        }
        print(f"{nome:22s} " + "  ".join(
            f"{m}={v['media']:.3f}" for m, v in comparacao[nome].items()))

    escolhido = max(comparacao, key=lambda n: comparacao[n]["f1_macro"]["media"])
    modelo = candidatos()[escolhido].fit(X_treino, y_treino)
    previsto = modelo.predict(X_teste)

    teste = {
        "acuracia": round(float(accuracy_score(y_teste, previsto)), 4),
        "f1_macro": round(float(f1_score(y_teste, previsto, average="macro")), 4),
        "por_classe": classification_report(y_teste, previsto, labels=CLASSES, output_dict=True),
        "matriz_confusao": {
            "ordem": CLASSES,
            "valores": confusion_matrix(y_teste, previsto, labels=CLASSES).tolist(),
        },
        "linha_de_base_classe_mais_comum": round(float((y_teste == y_treino.mode()[0]).mean()), 4),
    }

    # Modelo final: mesmo algoritmo, treinado com todas as linhas.
    final = candidatos()[escolhido].fit(X, y)
    versao = f"{escolhido}-{datetime.now(timezone.utc):%Y%m%d}"
    pacote = {
        "pipeline": final,
        "versao": versao,
        "algoritmo": escolhido,
        "entradas": ENTRADAS,
        "classes": list(final.classes_),
        "metricas_teste": {k: teste[k] for k in ("acuracia", "f1_macro")},
    }
    MODELO.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(pacote, MODELO, compress=3)

    RELATORIO.write_text(
        json.dumps(
            {"versao": versao, "escolhido": escolhido, "criterio": "maior F1 macro na validação cruzada",
             "validacao_cruzada": comparacao, "teste_20pct": teste},
            indent=2, ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    print(f"\nEscolhido: {escolhido} | teste: acurácia {teste['acuracia']:.3f}, "
          f"F1 macro {teste['f1_macro']:.3f}, recall alto {teste['por_classe']['alto']['recall']:.3f}")
    print(f"Modelo salvo em {MODELO}")


if __name__ == "__main__":
    main()
