from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

RAIZ_REPO = Path(__file__).resolve().parents[2]


class Configuracoes(BaseSettings):
    """Lidas de variáveis de ambiente (ou do arquivo .env na pasta backend/).

    No Azure, DATABASE_URL e API_KEY vêm do Key Vault como segredos do
    Container App; nunca ficam no código nem no repositório.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://equilibra:equilibra@localhost:5432/equilibra"
    api_key: str = "troque-esta-chave"
    model_path: Path = RAIZ_REPO / "ml" / "models" / "modelo_burnout.joblib"


@lru_cache
def obter_configuracoes() -> Configuracoes:
    return Configuracoes()
