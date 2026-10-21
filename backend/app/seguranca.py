import secrets

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader

from .config import obter_configuracoes

cabecalho_chave = APIKeyHeader(name="X-API-Key", auto_error=False)


def exigir_chave(chave: str | None = Security(cabecalho_chave)) -> None:
    """Toda rota de dados exige o cabeçalho X-API-Key."""
    esperada = obter_configuracoes().api_key
    if not chave or not secrets.compare_digest(chave, esperada):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Chave de API inválida ou ausente")
