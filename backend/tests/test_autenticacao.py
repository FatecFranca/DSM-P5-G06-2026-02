"""Testes de unidade do módulo de autenticação (sem passar pela API)."""

import uuid
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi import HTTPException

from pydantic import ValidationError

from app.autenticacao import (
    ALGORITMO,
    LimiteDeTentativas,
    criar_token,
    gerar_hash,
    ler_token,
    senha_confere,
)
from app.config import API_KEY_EXEMPLO, JWT_SEGREDO_EXEMPLO, Configuracoes, obter_configuracoes


def test_hash_nao_guarda_a_senha_e_confere():
    hash_salvo = gerar_hash("senha-forte-123")
    assert "senha-forte-123" not in hash_salvo
    assert hash_salvo.startswith("$argon2")
    assert senha_confere("senha-forte-123", hash_salvo)
    assert not senha_confere("senha-errada", hash_salvo)


def test_mesma_senha_gera_hashes_diferentes():
    assert gerar_hash("igual-igual") != gerar_hash("igual-igual")  # sal aleatório


def test_senha_sem_conta_ou_hash_invalido_nunca_confere():
    assert not senha_confere("qualquer", None)
    assert not senha_confere("qualquer", "isto-nao-e-um-hash")


def test_token_ida_e_volta():
    uid = uuid.uuid4()
    token, expira_em = criar_token(uid)
    assert ler_token(token) == uid
    assert expira_em > datetime.now(timezone.utc)


def _token_manual(dados: dict, segredo: str | None = None) -> str:
    return jwt.encode(dados, segredo or obter_configuracoes().jwt_segredo, algorithm=ALGORITMO)


@pytest.mark.parametrize(
    "token",
    [
        "nao-e-um-token",
        _token_manual({"sub": str(uuid.uuid4()), "exp": datetime.now(timezone.utc) - timedelta(seconds=1)}),
        _token_manual({"sub": str(uuid.uuid4())}),  # sem validade
        _token_manual({"sub": "nao-e-uuid", "exp": datetime.now(timezone.utc) + timedelta(hours=1)}),
        _token_manual(
            {"sub": str(uuid.uuid4()), "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
            segredo="outro-segredo-com-mais-de-32-caracteres!!",
        ),
    ],
    ids=["lixo", "expirado", "sem-exp", "sub-invalido", "assinatura-errada"],
)
def test_token_invalido_gera_401(token):
    with pytest.raises(HTTPException) as erro:
        ler_token(token)
    assert erro.value.status_code == 401


# ---------- limite de tentativas ----------

class RelogioFalso:
    def __init__(self):
        self.agora = 1000.0

    def __call__(self) -> float:
        return self.agora


def test_limite_bloqueia_apos_o_maximo_de_falhas():
    limite = LimiteDeTentativas(maximo=3, janela_segundos=60, relogio=RelogioFalso())
    for _ in range(2):
        limite.registrar_falha("ana@x.com")
    assert not limite.bloqueado("ana@x.com")
    limite.registrar_falha("ana@x.com")
    assert limite.bloqueado("ana@x.com")
    assert not limite.bloqueado("bia@x.com")  # cada e-mail tem a sua contagem


def test_limite_libera_quando_a_janela_passa():
    relogio = RelogioFalso()
    limite = LimiteDeTentativas(maximo=2, janela_segundos=60, relogio=relogio)
    limite.registrar_falha("ana@x.com")
    limite.registrar_falha("ana@x.com")
    assert limite.bloqueado("ana@x.com")
    relogio.agora += 61
    assert not limite.bloqueado("ana@x.com")


def test_limpar_zera_a_contagem():
    limite = LimiteDeTentativas(maximo=1, janela_segundos=60, relogio=RelogioFalso())
    limite.registrar_falha("ana@x.com")
    limite.limpar("ana@x.com")
    assert not limite.bloqueado("ana@x.com")


def test_limite_descarta_chaves_vencidas_quando_ha_muitas():
    relogio = RelogioFalso()
    limite = LimiteDeTentativas(maximo=5, janela_segundos=60, relogio=relogio)
    limite.MAXIMO_CHAVES = 3
    for i in range(3):
        limite.registrar_falha(f"u{i}@x.com")
    relogio.agora += 61
    limite.registrar_falha("novo@x.com")
    assert list(limite._falhas) == ["novo@x.com"]


# ---------- configuração ----------

def test_segredo_jwt_curto_e_recusado():
    with pytest.raises(ValidationError, match="32 caracteres"):
        Configuracoes(jwt_segredo="curto")


@pytest.mark.parametrize(
    ("campos", "variavel"),
    [
        ({"api_key": "chave-de-producao-forte"}, "JWT_SEGREDO"),
        ({"jwt_segredo": "s" * 40}, "API_KEY"),
    ],
)
def test_producao_recusa_valores_de_exemplo(campos, variavel):
    base = {"ambiente": "producao", "jwt_segredo": JWT_SEGREDO_EXEMPLO, "api_key": API_KEY_EXEMPLO}
    with pytest.raises(ValidationError, match=variavel):
        Configuracoes(**{**base, **campos})


def test_producao_aceita_segredos_definidos():
    cfg = Configuracoes(ambiente="producao", jwt_segredo="s" * 40, api_key="chave-de-producao-forte")
    assert cfg.ambiente == "producao"
