"""Painel do estudante: média de todas as respostas e dicas personalizadas.

As dicas comparam a média do estudante com a dos estudantes de risco baixo na base de treino
(referencias_base.json, gerado por ml/src/gerar_referencias.py). As referências orientam, mas não são
metas clínicas: a base é provavelmente sintética, e o aviso de "não é diagnóstico" vai sempre junto.
"""

import json
from collections import Counter
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from . import classificador
from .models import Avaliacao
from .schemas import DicaPainel, PainelResposta, Probabilidades

ARQUIVO_REFERENCIAS = Path(__file__).with_name("referencias_base.json")

RESPOSTAS_NUMERICAS = (
    "nota_semestre_anterior",
    "horas_ia_semana",
    "horas_estudo_semana",
    "qtd_ferramentas_ia",
    "dependencia_ia",
    "ansiedade_provas",
)
RESPOSTAS_CATEGORICAS = (
    "area_curso",
    "ano_curso",
    "uso_principal_ia",
    "nivel_prompt",
    "politica_instituicao",
)

# Só gera dica quando a média está pior que a referência por mais que esta fração do desvio padrão:
# diferenças menores não dizem nada de útil sobre os hábitos do estudante.
MARGEM_EM_DESVIOS = 0.25
# Diferença mínima na chance de risco alto entre as duas últimas avaliações para falar em tendência.
MUDANCA_MINIMA_TENDENCIA = 0.05

NOTA_REFERENCIAS = (
    "As referências são a média dos estudantes de risco baixo na base usada para treinar o modelo "
    "(provavelmente sintética). Servem como orientação geral, não como meta."
)


@dataclass(frozen=True)
class RegraDeDica:
    variavel: str
    melhor_menor: bool  # True: quanto menor a média, melhor
    titulo: str
    texto: str  # recebe {media} e {referencia}


REGRAS = (
    RegraDeDica(
        "horas_ia_semana",
        melhor_menor=True,
        titulo="Reduza aos poucos as horas de IA",
        texto=(
            "Você usa IA em média {media} h por semana; entre estudantes de risco baixo, a média é "
            "{referencia} h. Troque parte desse tempo por estudo ativo: resolva exercícios e explique "
            "o conteúdo com suas palavras."
        ),
    ),
    RegraDeDica(
        "dependencia_ia",
        melhor_menor=True,
        titulo="Pratique estudar sem a IA",
        texto=(
            "Sua dependência de IA está em {media} de 10 (referência: {referencia}). Antes de pedir "
            "ajuda, tente resolver sozinho por 15 minutos e use a IA só para conferir."
        ),
    ),
    RegraDeDica(
        "ansiedade_provas",
        melhor_menor=True,
        titulo="Cuide da ansiedade antes das provas",
        texto=(
            "Sua ansiedade em provas está em {media} de 10 (referência: {referencia}). Faça revisões "
            "curtas ao longo da semana e durma bem na véspera. Se ela atrapalhar sua rotina, procure o "
            "apoio da sua instituição ou um profissional de saúde."
        ),
    ),
    RegraDeDica(
        "horas_estudo_semana",
        melhor_menor=False,
        titulo="Reserve mais tempo de estudo sem IA",
        texto=(
            "Você estuda sem IA {media} h por semana; a referência é {referencia} h. Comece com blocos "
            "fixos de 50 minutos na agenda e aumente aos poucos."
        ),
    ),
)

DICA_RESPOSTAS_PRONTAS = DicaPainel(
    titulo="Use a IA para aprender, não só para ter a resposta",
    texto=(
        "Seu uso mais comum é obter respostas prontas. Peça explicações e exemplos, e tente refazer "
        "o exercício sem olhar: é assim que o conteúdo fica."
    ),
    tipo="melhorar",
)

DICA_CONTINUE = DicaPainel(
    titulo="Seus hábitos estão no caminho certo",
    texto=(
        "Suas médias estão próximas das de estudantes com risco baixo. Continue com as pausas "
        "regulares e usando a IA como apoio, não como substituta do seu raciocínio."
    ),
    tipo="manter",
)


@lru_cache
def carregar_referencias() -> dict:
    return json.loads(ARQUIVO_REFERENCIAS.read_text(encoding="utf-8"))


def _numero(valor: float) -> str:
    """Número com uma casa decimal e vírgula, como se lê em português."""
    return f"{valor:.1f}".replace(".", ",")


def _media(valores: Sequence[float]) -> float:
    return round(sum(valores) / len(valores), 2)


def _mais_comum(valores: Sequence[str]) -> str:
    """Resposta mais frequente; no empate, a mais recente ([valores] em ordem cronológica)."""
    contagem = Counter(valores)
    maior = max(contagem.values())
    return next(v for v in reversed(valores) if contagem[v] == maior)


def _tendencia(avaliacoes: Sequence[Avaliacao]) -> str | None:
    """Compara a chance de risco alto das duas últimas avaliações."""
    if len(avaliacoes) < 2:
        return None
    mudanca = float(avaliacoes[-1].prob_alto) - float(avaliacoes[-2].prob_alto)
    if mudanca <= -MUDANCA_MINIMA_TENDENCIA:
        return "melhorando"
    if mudanca >= MUDANCA_MINIMA_TENDENCIA:
        return "piorando"
    return "estavel"


def gerar_dicas(medias: dict[str, float], mais_comuns: dict[str, str], referencias: dict) -> list[DicaPainel]:
    """Dicas do que pode melhorar, da maior para a menor diferença em relação à referência."""
    candidatas = []
    for regra in REGRAS:
        media = medias[regra.variavel]
        referencia = referencias["media_risco_baixo"][regra.variavel]
        diferenca = media - referencia if regra.melhor_menor else referencia - media
        distancia = diferenca / referencias["desvio"][regra.variavel]
        if distancia > MARGEM_EM_DESVIOS:
            dica = DicaPainel(
                titulo=regra.titulo,
                texto=regra.texto.format(media=_numero(media), referencia=_numero(referencia)),
                tipo="melhorar",
                variavel=regra.variavel,
            )
            candidatas.append((distancia, dica))

    dicas = [dica for _, dica in sorted(candidatas, key=lambda par: par[0], reverse=True)]
    if mais_comuns["uso_principal_ia"] == "respostas_prontas":
        dicas.append(DICA_RESPOSTAS_PRONTAS)
    return dicas or [DICA_CONTINUE]


def montar_painel(avaliacoes: Sequence[Avaliacao]) -> PainelResposta:
    """Monta o painel a partir de todas as avaliações do usuário, em ordem cronológica."""
    referencias = carregar_referencias()
    base = {
        "aviso": classificador.AVISO,
        "referencias_risco_baixo": referencias["media_risco_baixo"],
        "nota_referencias": NOTA_REFERENCIAS,
    }
    if not avaliacoes:
        return PainelResposta(total_avaliacoes=0, **base)

    medias = {
        nome: _media([float(getattr(a, nome)) for a in avaliacoes]) for nome in RESPOSTAS_NUMERICAS
    }
    medias["assinatura_paga"] = _media([1.0 if a.assinatura_paga else 0.0 for a in avaliacoes])
    mais_comuns = {nome: _mais_comum([getattr(a, nome) for a in avaliacoes]) for nome in RESPOSTAS_CATEGORICAS}
    niveis = Counter(a.nivel_risco for a in avaliacoes)
    ultima = avaliacoes[-1]

    return PainelResposta(
        total_avaliacoes=len(avaliacoes),
        primeira_em=avaliacoes[0].criado_em,
        ultima_em=ultima.criado_em,
        risco_atual=ultima.nivel_risco,
        tendencia=_tendencia(avaliacoes),
        contagem_risco={nivel: niveis.get(nivel, 0) for nivel in ("baixo", "medio", "alto")},
        probabilidades_medias=Probabilidades(
            baixo=_media([float(a.prob_baixo) for a in avaliacoes]),
            medio=_media([float(a.prob_medio) for a in avaliacoes]),
            alto=_media([float(a.prob_alto) for a in avaliacoes]),
        ),
        medias=medias,
        mais_comuns=mais_comuns,
        dicas=gerar_dicas(medias, mais_comuns, referencias),
        apoio=classificador.APOIO if ultima.nivel_risco == "alto" else None,
        **base,
    )
