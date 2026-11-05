"""Testes do painel do estudante: cálculo das médias, dicas e acesso pela API."""

import json
import sys
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pandas as pd
import pytest

from app.config import RAIZ_REPO
from app.models import Avaliacao
from app.painel import ARQUIVO_REFERENCIAS, carregar_referencias, gerar_dicas, montar_painel
from app.schemas import Questionario

SENHA = "senha-segura-123"
BOM = {
    "nota_semestre_anterior": Decimal("8"),
    "horas_ia_semana": Decimal("3"),
    "horas_estudo_semana": Decimal("15"),
    "qtd_ferramentas_ia": 2,
    "dependencia_ia": 2,
    "ansiedade_provas": 3,
    "assinatura_paga": False,
    "area_curso": "exatas",
    "ano_curso": "terceiro_ano",
    "uso_principal_ia": "gerar_ideias",
    "nivel_prompt": "avancado",
    "politica_instituicao": "incentivado",
}
RUIM = {
    **BOM,
    "horas_ia_semana": Decimal("30"),
    "horas_estudo_semana": Decimal("4"),
    "dependencia_ia": 9,
    "ansiedade_provas": 9,
    "uso_principal_ia": "respostas_prontas",
}


def avaliacao(campos=BOM, nivel="baixo", prob_alto="0.1", dias=0, **extra) -> Avaliacao:
    alto = Decimal(prob_alto)
    return Avaliacao(
        **{**campos, **extra},
        nivel_risco=nivel,
        prob_baixo=(Decimal("1") - alto) / 2,
        prob_medio=(Decimal("1") - alto) / 2,
        prob_alto=alto,
        versao_modelo="teste",
        criado_em=datetime(2026, 11, 1, tzinfo=timezone.utc) + timedelta(days=dias),
    )


# ---------- médias ----------

def test_sem_avaliacoes_devolve_painel_vazio_com_aviso():
    p = montar_painel([])
    assert p.total_avaliacoes == 0
    assert p.medias == {}
    assert p.dicas == []
    assert p.risco_atual is None
    assert p.aviso


def test_media_de_todas_as_respostas_numericas():
    p = montar_painel([avaliacao(horas_ia_semana=Decimal("10")), avaliacao(horas_ia_semana=Decimal("21"), dias=1)])
    assert p.total_avaliacoes == 2
    assert p.medias["horas_ia_semana"] == 15.5
    assert p.medias["ansiedade_provas"] == 3
    assert p.medias["nota_semestre_anterior"] == 8


def test_assinatura_paga_vira_fracao_das_vezes():
    p = montar_painel([avaliacao(assinatura_paga=True), avaliacao(dias=1), avaliacao(dias=2), avaliacao(assinatura_paga=True, dias=3)])
    assert p.medias["assinatura_paga"] == 0.5


def test_painel_cobre_todas_as_12_perguntas_do_questionario():
    p = montar_painel([avaliacao()])
    assert set(p.medias) | set(p.mais_comuns) == set(Questionario.model_fields)


def test_perguntas_de_escolha_mostram_a_resposta_mais_comum():
    p = montar_painel([avaliacao(area_curso="saude"), avaliacao(area_curso="artes", dias=1), avaliacao(area_curso="saude", dias=2)])
    assert p.mais_comuns["area_curso"] == "saude"


def test_empate_na_mais_comum_fica_com_a_mais_recente():
    p = montar_painel([avaliacao(area_curso="saude"), avaliacao(area_curso="artes", dias=1)])
    assert p.mais_comuns["area_curso"] == "artes"


def test_probabilidades_medias_e_contagem_por_nivel():
    p = montar_painel([avaliacao(nivel="alto", prob_alto="0.8"), avaliacao(nivel="baixo", prob_alto="0.2", dias=1), avaliacao(nivel="baixo", prob_alto="0.2", dias=2)])
    assert p.probabilidades_medias.alto == 0.4
    assert p.contagem_risco == {"baixo": 2, "medio": 0, "alto": 1}


def test_risco_atual_e_as_datas_vem_da_ordem_cronologica():
    p = montar_painel([avaliacao(nivel="alto", prob_alto="0.8"), avaliacao(nivel="medio", prob_alto="0.4", dias=5)])
    assert p.risco_atual == "medio"
    assert p.ultima_em > p.primeira_em


# ---------- tendência ----------

@pytest.mark.parametrize(
    ("anterior", "ultima", "esperada"),
    [("0.60", "0.30", "melhorando"), ("0.30", "0.60", "piorando"), ("0.30", "0.32", "estavel")],
)
def test_tendencia_compara_as_duas_ultimas(anterior, ultima, esperada):
    p = montar_painel([avaliacao(prob_alto=anterior), avaliacao(prob_alto=ultima, dias=1)])
    assert p.tendencia == esperada


def test_uma_avaliacao_so_nao_tem_tendencia():
    assert montar_painel([avaliacao()]).tendencia is None


# ---------- dicas ----------

def test_habitos_bons_recebem_dica_de_manter():
    dicas = montar_painel([avaliacao()]).dicas
    assert [d.tipo for d in dicas] == ["manter"]


def test_habitos_ruins_recebem_uma_dica_por_problema_com_os_numeros():
    dicas = montar_painel([avaliacao(RUIM, nivel="alto", prob_alto="0.9")]).dicas
    variaveis = {d.variavel for d in dicas}
    assert variaveis == {"horas_ia_semana", "dependencia_ia", "ansiedade_provas", "horas_estudo_semana", None}
    assert all(d.tipo == "melhorar" for d in dicas)

    horas = next(d for d in dicas if d.variavel == "horas_ia_semana")
    assert "30,0 h" in horas.texto  # a média do estudante, em português
    assert "4,6 h" in horas.texto  # a referência da base


def test_dicas_vem_da_maior_para_a_menor_diferenca():
    referencias = carregar_referencias()
    medias = {
        **referencias["media_risco_baixo"],
        "horas_ia_semana": referencias["media_risco_baixo"]["horas_ia_semana"] + referencias["desvio"]["horas_ia_semana"],
        "ansiedade_provas": referencias["media_risco_baixo"]["ansiedade_provas"] + 2 * referencias["desvio"]["ansiedade_provas"],
    }
    dicas = gerar_dicas(medias, {"uso_principal_ia": "gerar_ideias"}, referencias)
    assert [d.variavel for d in dicas] == ["ansiedade_provas", "horas_ia_semana"]


def test_diferenca_pequena_nao_gera_dica():
    referencias = carregar_referencias()
    medias = {
        **referencias["media_risco_baixo"],
        "horas_ia_semana": referencias["media_risco_baixo"]["horas_ia_semana"] + 0.2 * referencias["desvio"]["horas_ia_semana"],
    }
    dicas = gerar_dicas(medias, {"uso_principal_ia": "gerar_ideias"}, referencias)
    assert [d.tipo for d in dicas] == ["manter"]


def test_estudar_mais_que_a_referencia_nao_gera_dica_de_estudo():
    dicas = montar_painel([avaliacao(horas_estudo_semana=Decimal("40"))]).dicas
    assert all(d.variavel != "horas_estudo_semana" for d in dicas)


def test_estudar_menos_que_a_referencia_gera_dica_de_estudo():
    dicas = montar_painel([avaliacao(horas_estudo_semana=Decimal("2"))]).dicas
    assert [d.variavel for d in dicas] == ["horas_estudo_semana"]


def test_uso_para_respostas_prontas_gera_dica_propria():
    dicas = montar_painel([avaliacao(uso_principal_ia="respostas_prontas")]).dicas
    assert any("Use a IA para aprender" in d.titulo for d in dicas)


def test_nao_ha_dica_sobre_o_que_nao_muda_o_risco_na_base():
    """Número de ferramentas é praticamente igual nos três níveis (2,8): não vira conselho."""
    dicas = montar_painel([avaliacao(qtd_ferramentas_ia=10)]).dicas
    assert [d.tipo for d in dicas] == ["manter"]


def test_apoio_do_cvv_so_quando_o_risco_atual_e_alto():
    assert "188" in montar_painel([avaliacao(nivel="alto", prob_alto="0.8")]).apoio
    assert montar_painel([avaliacao(nivel="alto", prob_alto="0.8"), avaliacao(nivel="baixo", dias=1)]).apoio is None


def test_aviso_de_que_nao_e_diagnostico_vai_sempre():
    assert "não um diagnóstico" in montar_painel([avaliacao()]).aviso


# ---------- referências ----------

def test_referencias_batem_com_a_base_de_treino():
    """Os números das dicas precisam vir dos dados: se a base mudar, regenere o arquivo."""
    sys.path.insert(0, str(RAIZ_REPO / "ml" / "src"))
    from gerar_referencias import calcular_referencias  # noqa: PLC0415
    from preparar_base import ORIGEM  # noqa: PLC0415

    calculadas = calcular_referencias(pd.read_csv(ORIGEM))
    assert calculadas == json.loads(ARQUIVO_REFERENCIAS.read_text(encoding="utf-8"))


def test_referencias_mostram_que_risco_alto_usa_mais_ia_que_risco_baixo():
    r = carregar_referencias()
    assert r["media_risco_alto"]["horas_ia_semana"] > r["media_risco_baixo"]["horas_ia_semana"]
    assert r["media_risco_alto"]["horas_estudo_semana"] < r["media_risco_baixo"]["horas_estudo_semana"]


# ---------- API ----------

def portador(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def criar_conta(cliente, email="ana@exemplo.com") -> tuple[str, str]:
    uid = str(uuid.uuid4())
    cliente.post("/usuarios", json={"id": uid, "consentimento": True})
    r = cliente.post("/auth/cadastro", json={"usuario_id": uid, "email": email, "senha": SENHA, "consentimento": True})
    return uid, r.json()["token"]


def test_painel_exige_login(cliente):
    uid, _ = criar_conta(cliente)
    assert cliente.get(f"/usuarios/{uid}/painel").status_code == 401


def test_usuario_anonimo_nao_tem_painel(cliente):
    uid = str(uuid.uuid4())
    cliente.post("/usuarios", json={"id": uid, "consentimento": True})
    assert cliente.get(f"/usuarios/{uid}/painel").status_code == 401


def test_painel_de_outra_pessoa_e_recusado(cliente):
    ana, _ = criar_conta(cliente)
    _, token_bia = criar_conta(cliente, "bia@exemplo.com")
    assert cliente.get(f"/usuarios/{ana}/painel", headers=portador(token_bia)).status_code == 403


def test_token_de_conta_nao_abre_painel_de_anonimo(cliente):
    _, token = criar_conta(cliente)
    anonimo = str(uuid.uuid4())
    cliente.post("/usuarios", json={"id": anonimo, "consentimento": True})
    assert cliente.get(f"/usuarios/{anonimo}/painel", headers=portador(token)).status_code == 403


def test_painel_de_conta_apagada_da_404(cliente):
    uid, token = criar_conta(cliente)
    cliente.delete(f"/usuarios/{uid}", headers=portador(token))
    assert cliente.get(f"/usuarios/{uid}/painel", headers=portador(token)).status_code == 404


def test_conta_sem_avaliacoes_tem_painel_vazio(cliente):
    uid, token = criar_conta(cliente)
    r = cliente.get(f"/usuarios/{uid}/painel", headers=portador(token))
    assert r.status_code == 200
    assert r.json()["total_avaliacoes"] == 0
    assert r.json()["referencias_risco_baixo"]["horas_ia_semana"] == 4.64


def test_painel_com_avaliacoes_reais_do_modelo(cliente, respostas):
    uid, token = criar_conta(cliente)
    outro, token_outro = criar_conta(cliente, "bia@exemplo.com")
    for horas in (30, 10):
        cliente.post(
            "/predicoes",
            headers=portador(token),
            json={"usuario_id": uid, "respostas": {**respostas, "horas_ia_semana": horas}},
        )
    cliente.post("/predicoes", headers=portador(token_outro), json={"usuario_id": outro, "respostas": respostas})

    corpo = cliente.get(f"/usuarios/{uid}/painel", headers=portador(token)).json()

    assert corpo["total_avaliacoes"] == 2  # só as dela
    assert corpo["medias"]["horas_ia_semana"] == 20
    assert corpo["mais_comuns"]["uso_principal_ia"] == "respostas_prontas"
    assert corpo["dicas"]
    assert corpo["aviso"]
    assert corpo["risco_atual"] in {"baixo", "medio", "alto"}
    assert abs(sum(corpo["probabilidades_medias"].values()) - 1) < 0.02
