"""API do Equilibra — classificação de risco de burnout em estudantes.

Rodar localmente (na pasta backend/):
    uvicorn app.main:app --reload
Documentação interativa: http://localhost:8000/docs
"""

from fastapi import Depends, FastAPI

from . import classificador
from .routers import auth, predicoes, usuarios
from .schemas import Saude
from .seguranca import exigir_chave

app = FastAPI(
    title="Equilibra API",
    version="0.1.0",
    description=(
        "Classifica o risco de burnout (baixo, médio, alto) de estudantes a partir de "
        "hábitos de estudo e de uso de IA generativa. Projeto Interdisciplinar, "
        "5º semestre DSM, Fatec Franca. Autoavaliação educativa, não diagnóstico."
    ),
)

protegido = [Depends(exigir_chave)]
app.include_router(auth.router, dependencies=protegido)
app.include_router(usuarios.router, dependencies=protegido)
app.include_router(predicoes.router, dependencies=protegido)


@app.get("/saude", response_model=Saude, tags=["Infraestrutura"])
def saude():
    """Verificação de vida usada pelo Azure Container Apps (sem chave)."""
    return Saude(status="ok", versao_modelo=classificador.versao_modelo())
