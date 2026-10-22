"""Os testes usam um SQLite temporário, sem precisar de PostgreSQL rodando."""

import os
import tempfile
from pathlib import Path

import pytest

_banco = Path(tempfile.mkdtemp()) / "teste.db"
os.environ["DATABASE_URL"] = f"sqlite:///{_banco}"
os.environ["API_KEY"] = "chave-de-teste"
os.environ["JWT_SEGREDO"] = "segredo-de-teste-com-mais-de-32-caracteres"

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import event  # noqa: E402

from app.autenticacao import limite_de_login  # noqa: E402
from app.database import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@event.listens_for(engine, "connect")
def _ligar_chaves_estrangeiras(conexao, _):
    conexao.execute("PRAGMA foreign_keys=ON")


@pytest.fixture(autouse=True)
def banco_limpo():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    limite_de_login.limpar()
    yield


@pytest.fixture
def cliente():
    with TestClient(app, headers={"X-API-Key": "chave-de-teste"}) as c:
        yield c


@pytest.fixture
def respostas():
    return {
        "area_curso": "exatas",
        "ano_curso": "pos_graduacao",
        "nota_semestre_anterior": 7.0,
        "horas_ia_semana": 30,
        "horas_estudo_semana": 5,
        "qtd_ferramentas_ia": 4,
        "dependencia_ia": 9,
        "ansiedade_provas": 9,
        "assinatura_paga": True,
        "uso_principal_ia": "respostas_prontas",
        "nivel_prompt": "iniciante",
        "politica_instituicao": "proibido",
    }
