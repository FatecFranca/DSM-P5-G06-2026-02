"""Testes das contas: cadastro, login, token e proteção dos dados de quem tem conta."""

import uuid

import pytest

from app.database import SessaoLocal
from app.models import Usuario

SENHA = "senha-segura-123"


def novo_usuario(cliente) -> str:
    uid = str(uuid.uuid4())
    assert cliente.post("/usuarios", json={"id": uid, "consentimento": True}).status_code == 201
    return uid


def cadastrar(cliente, uid: str, email: str = "ana@exemplo.com", senha: str = SENHA):
    return cliente.post(
        "/auth/cadastro",
        json={"usuario_id": uid, "email": email, "senha": senha, "consentimento": True},
    )


def entrar(cliente, email: str = "ana@exemplo.com", senha: str = SENHA, anonimo: str | None = None):
    corpo = {"email": email, "senha": senha}
    if anonimo:
        corpo["usuario_id_anonimo"] = anonimo
    return cliente.post("/auth/login", json=corpo)


def portador(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def avaliar(cliente, uid: str, respostas: dict, token: str | None = None):
    return cliente.post(
        "/predicoes",
        json={"usuario_id": uid, "respostas": respostas},
        headers=portador(token) if token else None,
    )


# ---------- cadastro ----------

def test_cadastro_devolve_token_e_conta(cliente):
    uid = novo_usuario(cliente)
    r = cadastrar(cliente, uid, email="Ana@Exemplo.com")
    assert r.status_code == 201
    corpo = r.json()
    assert corpo["usuario_id"] == uid
    assert corpo["email"] == "ana@exemplo.com"  # normalizado
    assert corpo["tipo"] == "bearer"

    me = cliente.get("/auth/me", headers=portador(corpo["token"]))
    assert me.status_code == 200
    assert me.json()["email"] == "ana@exemplo.com"


@pytest.mark.parametrize(
    "alteracao",
    [{"senha": "curta"}, {"email": "nao-e-email"}, {"consentimento": False}],
    ids=["senha-curta", "email-invalido", "sem-consentimento"],
)
def test_cadastro_valida_entrada(cliente, alteracao):
    uid = novo_usuario(cliente)
    corpo = {"usuario_id": uid, "email": "ana@exemplo.com", "senha": SENHA, "consentimento": True}
    corpo.update(alteracao)
    assert cliente.post("/auth/cadastro", json=corpo).status_code == 422


def test_cadastro_exige_consentimento_anterior(cliente):
    assert cadastrar(cliente, str(uuid.uuid4())).status_code == 404


def test_email_duplicado_e_recusado_sem_diferenciar_maiusculas(cliente):
    assert cadastrar(cliente, novo_usuario(cliente)).status_code == 201
    assert cadastrar(cliente, novo_usuario(cliente), email="ANA@exemplo.com").status_code == 409


def test_aparelho_com_conta_nao_cadastra_de_novo(cliente):
    uid = novo_usuario(cliente)
    assert cadastrar(cliente, uid).status_code == 201
    assert cadastrar(cliente, uid, email="outro@exemplo.com").status_code == 409


def test_cadastro_atualiza_versao_do_termo(cliente):
    uid = novo_usuario(cliente)
    cadastrar(cliente, uid)
    with SessaoLocal() as sessao:
        usuario = sessao.get(Usuario, uuid.UUID(uid))
        assert usuario.versao_termo == "2.0"
        assert usuario.senha_hash.startswith("$argon2")


# ---------- login ----------

def test_login_com_email_em_maiusculas(cliente):
    uid = novo_usuario(cliente)
    cadastrar(cliente, uid)
    r = entrar(cliente, email="ANA@EXEMPLO.COM")
    assert r.status_code == 200
    assert r.json()["usuario_id"] == uid


def test_login_nao_revela_se_email_existe(cliente):
    cadastrar(cliente, novo_usuario(cliente))
    senha_errada = entrar(cliente, senha="senha-errada-000")
    sem_conta = entrar(cliente, email="ninguem@exemplo.com")
    assert senha_errada.status_code == sem_conta.status_code == 401
    assert senha_errada.json() == sem_conta.json()


def test_token_invalido_e_recusado(cliente):
    assert cliente.get("/auth/me").status_code == 401
    assert cliente.get("/auth/me", headers=portador("token-falso")).status_code == 401


def test_login_une_historico_do_aparelho_anonimo(cliente, respostas):
    conta = novo_usuario(cliente)
    token = cadastrar(cliente, conta).json()["token"]
    avaliar(cliente, conta, respostas, token)

    outro_aparelho = novo_usuario(cliente)
    avaliar(cliente, outro_aparelho, respostas)
    avaliar(cliente, outro_aparelho, respostas)

    token = entrar(cliente, anonimo=outro_aparelho).json()["token"]
    historico = cliente.get(f"/usuarios/{conta}/avaliacoes", headers=portador(token))
    assert len(historico.json()) == 3
    assert cliente.get(f"/usuarios/{outro_aparelho}/avaliacoes").status_code == 404


def test_login_nunca_une_historico_de_outra_conta(cliente, respostas):
    ana = novo_usuario(cliente)
    cadastrar(cliente, ana)
    bia = novo_usuario(cliente)
    token_bia = cadastrar(cliente, bia, email="bia@exemplo.com").json()["token"]
    avaliar(cliente, bia, respostas, token_bia)

    assert entrar(cliente, anonimo=bia).status_code == 200
    assert len(cliente.get(f"/usuarios/{bia}/avaliacoes", headers=portador(token_bia)).json()) == 1


# ---------- proteção dos dados ----------

def test_dados_de_conta_exigem_token_do_dono(cliente, respostas):
    ana = novo_usuario(cliente)
    token_ana = cadastrar(cliente, ana).json()["token"]
    bia = novo_usuario(cliente)
    token_bia = cadastrar(cliente, bia, email="bia@exemplo.com").json()["token"]

    rota = f"/usuarios/{ana}/avaliacoes"
    assert cliente.get(rota).status_code == 401
    assert cliente.get(rota, headers=portador(token_bia)).status_code == 403
    assert cliente.get(rota, headers=portador(token_ana)).status_code == 200

    assert avaliar(cliente, ana, respostas).status_code == 401
    assert avaliar(cliente, ana, respostas, token_bia).status_code == 403
    assert avaliar(cliente, ana, respostas, token_ana).status_code == 201

    assert cliente.delete(f"/usuarios/{ana}").status_code == 401
    assert cliente.delete(f"/usuarios/{ana}", headers=portador(token_bia)).status_code == 403


def test_usuario_anonimo_continua_sem_token(cliente, respostas):
    uid = novo_usuario(cliente)
    assert avaliar(cliente, uid, respostas).status_code == 201
    assert cliente.get(f"/usuarios/{uid}/avaliacoes").status_code == 200


def test_apagar_conta_remove_login(cliente):
    uid = novo_usuario(cliente)
    token = cadastrar(cliente, uid).json()["token"]
    assert cliente.delete(f"/usuarios/{uid}", headers=portador(token)).status_code == 204
    assert entrar(cliente).status_code == 401
    assert cliente.get("/auth/me", headers=portador(token)).status_code == 401


# ---------- força bruta e consentimento ----------

def test_login_bloqueia_apos_muitas_senhas_erradas(cliente):
    cadastrar(cliente, novo_usuario(cliente))
    for _ in range(5):
        assert entrar(cliente, senha="senha-errada-000").status_code == 401

    bloqueado = entrar(cliente)  # até a senha certa é barrada durante o bloqueio
    assert bloqueado.status_code == 429
    assert cadastrar(cliente, novo_usuario(cliente), email="bia@exemplo.com").status_code == 201
    assert entrar(cliente, email="bia@exemplo.com").status_code == 200  # outros e-mails seguem livres


def test_login_certo_zera_as_falhas(cliente):
    cadastrar(cliente, novo_usuario(cliente))
    for _ in range(4):
        entrar(cliente, senha="senha-errada-000")
    assert entrar(cliente).status_code == 200
    for _ in range(4):
        entrar(cliente, senha="senha-errada-000")
    assert entrar(cliente).status_code == 200


def test_cadastro_preserva_a_data_do_primeiro_consentimento(cliente):
    uid = novo_usuario(cliente)
    with SessaoLocal() as sessao:
        primeiro_aceite = sessao.get(Usuario, uuid.UUID(uid)).consentimento_em

    cadastrar(cliente, uid)
    with SessaoLocal() as sessao:
        usuario = sessao.get(Usuario, uuid.UUID(uid))
        assert usuario.consentimento_em == primeiro_aceite
        assert usuario.conta_criada_em is not None
