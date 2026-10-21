"""Tabelas do banco (espelham database/schema.sql)."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    consentimento_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    versao_termo: Mapped[str] = mapped_column(String(10), default="1.0")
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    avaliacoes: Mapped[list["Avaliacao"]] = relationship(
        back_populates="usuario", cascade="all, delete-orphan", passive_deletes=True
    )


class Avaliacao(Base):
    __tablename__ = "avaliacoes"
    __table_args__ = (Index("ix_avaliacoes_usuario_data", "usuario_id", "criado_em"),)

    # BigInteger no PostgreSQL; Integer no SQLite dos testes (autoincremento).
    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True
    )
    usuario_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("usuarios.id", ondelete="CASCADE"), index=True
    )
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    area_curso: Mapped[str] = mapped_column(String(20))
    ano_curso: Mapped[str] = mapped_column(String(20))
    nota_semestre_anterior: Mapped[Decimal] = mapped_column(Numeric(4, 2))
    horas_ia_semana: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    horas_estudo_semana: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    qtd_ferramentas_ia: Mapped[int] = mapped_column(SmallInteger)
    dependencia_ia: Mapped[int] = mapped_column(SmallInteger)
    ansiedade_provas: Mapped[int] = mapped_column(SmallInteger)
    assinatura_paga: Mapped[bool]
    uso_principal_ia: Mapped[str] = mapped_column(String(30))
    nivel_prompt: Mapped[str] = mapped_column(String(20))
    politica_instituicao: Mapped[str] = mapped_column(String(30))

    nivel_risco: Mapped[str] = mapped_column(String(10))
    prob_baixo: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    prob_medio: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    prob_alto: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    versao_modelo: Mapped[str] = mapped_column(String(60))

    usuario: Mapped[Usuario] = relationship(back_populates="avaliacoes")
