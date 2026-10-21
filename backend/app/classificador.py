"""Carrega o modelo treinado em ml/ e faz as classificações."""

from functools import lru_cache

import joblib
import pandas as pd

from .config import obter_configuracoes
from .schemas import Questionario

AVISO = (
    "Esta é uma autoavaliação educativa, não um diagnóstico. "
    "Em caso de sofrimento, procure um profissional de saúde."
)
APOIO = "CVV – Centro de Valorização da Vida: ligue 188 (gratuito, 24h) ou acesse cvv.org.br."

ORIENTACOES = {
    "baixo": [
        "Seu equilíbrio parece bom. Mantenha pausas regulares nos estudos.",
        "Continue usando a IA como apoio, não como substituta do seu raciocínio.",
    ],
    "medio": [
        "Reserve blocos de estudo sem IA para fixar o conteúdo.",
        "Faça pausas curtas a cada 50 minutos de estudo.",
        "Observe se a ansiedade antes das provas está aumentando.",
    ],
    "alto": [
        "Reduza gradualmente as horas de uso de IA e alterne com estudo ativo.",
        "Converse com alguém de confiança ou com o apoio da sua instituição.",
        "Durma bem e evite estudar até tarde na véspera das provas.",
    ],
}


@lru_cache
def carregar_modelo() -> dict:
    return joblib.load(obter_configuracoes().model_path)


def versao_modelo() -> str:
    return carregar_modelo()["versao"]


def classificar(respostas: Questionario) -> tuple[str, dict[str, float]]:
    pacote = carregar_modelo()
    linha = respostas.model_dump()
    linha["assinatura_paga"] = int(linha["assinatura_paga"])
    entrada = pd.DataFrame([linha])[pacote["entradas"]]

    pipeline = pacote["pipeline"]
    probs = pipeline.predict_proba(entrada)[0]
    probabilidades = {classe: round(float(p), 4) for classe, p in zip(pipeline.classes_, probs)}
    nivel = max(probabilidades, key=probabilidades.get)
    return nivel, probabilidades
