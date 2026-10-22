from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

RAIZ_REPO = Path(__file__).resolve().parents[2]

# Valores de exemplo: servem só para rodar localmente. Em produção a API se recusa a subir com eles.
API_KEY_EXEMPLO = "troque-esta-chave"
JWT_SEGREDO_EXEMPLO = "troque-este-segredo-jwt-com-pelo-menos-32-caracteres"
TAMANHO_MINIMO_SEGREDO = 32


class Configuracoes(BaseSettings):
    """Lidas de variáveis de ambiente (ou do arquivo .env na pasta backend/).

    No Azure, DATABASE_URL, API_KEY e JWT_SEGREDO vêm do Key Vault como segredos do
    Container App; nunca ficam no código nem no repositório. Lá, AMBIENTE=producao.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    ambiente: Literal["desenvolvimento", "producao"] = "desenvolvimento"
    database_url: str = "postgresql+psycopg://equilibra:equilibra@localhost:5432/equilibra"
    api_key: str = API_KEY_EXEMPLO
    # Assina os tokens de login (JWT). Em produção: valor longo e aleatório.
    jwt_segredo: str = JWT_SEGREDO_EXEMPLO
    jwt_expiracao_horas: int = 24 * 7
    model_path: Path = RAIZ_REPO / "ml" / "models" / "modelo_burnout.joblib"

    @model_validator(mode="after")
    def _conferir_segredos(self) -> "Configuracoes":
        if len(self.jwt_segredo) < TAMANHO_MINIMO_SEGREDO:
            raise ValueError(f"JWT_SEGREDO precisa ter pelo menos {TAMANHO_MINIMO_SEGREDO} caracteres")
        if self.ambiente == "producao":
            if self.jwt_segredo == JWT_SEGREDO_EXEMPLO:
                raise ValueError("Defina JWT_SEGREDO: o valor de exemplo não pode ir para produção")
            if self.api_key == API_KEY_EXEMPLO:
                raise ValueError("Defina API_KEY: o valor de exemplo não pode ir para produção")
        return self


@lru_cache
def obter_configuracoes() -> Configuracoes:
    return Configuracoes()
