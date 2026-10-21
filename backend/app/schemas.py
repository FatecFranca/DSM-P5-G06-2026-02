"""Formatos de entrada e saída da API (validados pelo Pydantic)."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

AreaCurso = Literal["exatas", "negocios", "humanas", "saude", "artes"]
AnoCurso = Literal["primeiro_ano", "segundo_ano", "terceiro_ano", "quarto_ano", "pos_graduacao"]
UsoPrincipal = Literal[
    "depurar_codigo", "redigir_textos", "gerar_ideias", "resumir_leituras", "respostas_prontas"
]
NivelPrompt = Literal["iniciante", "intermediario", "avancado"]
Politica = Literal["proibido", "permitido_com_citacao", "incentivado"]
NivelRisco = Literal["baixo", "medio", "alto"]


class Questionario(BaseModel):
    """Respostas do estudante. Os nomes são os mesmos usados no modelo."""

    area_curso: AreaCurso
    ano_curso: AnoCurso
    nota_semestre_anterior: float = Field(ge=0, le=10, description="Média do semestre anterior, de 0 a 10")
    horas_ia_semana: float = Field(ge=0, le=80, description="Horas por semana usando IA generativa")
    horas_estudo_semana: float = Field(ge=0, le=80, description="Horas por semana estudando sem IA")
    qtd_ferramentas_ia: int = Field(ge=0, le=10, description="Quantas ferramentas de IA usa")
    dependencia_ia: int = Field(ge=1, le=10, description="Quanto sente que depende da IA (1 a 10)")
    ansiedade_provas: int = Field(ge=1, le=10, description="Ansiedade em provas (1 a 10)")
    assinatura_paga: bool
    uso_principal_ia: UsoPrincipal
    nivel_prompt: NivelPrompt
    politica_instituicao: Politica

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "area_curso": "exatas",
                "ano_curso": "terceiro_ano",
                "nota_semestre_anterior": 7.5,
                "horas_ia_semana": 18,
                "horas_estudo_semana": 8,
                "qtd_ferramentas_ia": 3,
                "dependencia_ia": 7,
                "ansiedade_provas": 8,
                "assinatura_paga": True,
                "uso_principal_ia": "depurar_codigo",
                "nivel_prompt": "intermediario",
                "politica_instituicao": "permitido_com_citacao",
            }
        }
    )


class Probabilidades(BaseModel):
    baixo: float
    medio: float
    alto: float


class PredicaoEntrada(BaseModel):
    usuario_id: uuid.UUID
    respostas: Questionario


class PredicaoResposta(BaseModel):
    avaliacao_id: int
    nivel_risco: NivelRisco
    probabilidades: Probabilidades
    orientacoes: list[str]
    apoio: str | None = Field(None, description="Preenchido quando o risco é alto")
    aviso: str
    versao_modelo: str
    criado_em: datetime


class UsuarioCriar(BaseModel):
    id: uuid.UUID = Field(description="UUID gerado no aparelho")
    consentimento: Literal[True] = Field(description="Aceite do termo de uso e privacidade")
    versao_termo: str = "1.0"


class UsuarioResposta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    consentimento_em: datetime
    versao_termo: str


class AvaliacaoResumo(BaseModel):
    id: int
    criado_em: datetime
    nivel_risco: NivelRisco
    probabilidades: Probabilidades
    horas_ia_semana: float
    ansiedade_provas: int


class Saude(BaseModel):
    status: str
    versao_modelo: str
