from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import obter_configuracoes

engine = create_engine(obter_configuracoes().database_url, pool_pre_ping=True)
SessaoLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def obter_sessao() -> Iterator[Session]:
    sessao = SessaoLocal()
    try:
        yield sessao
    finally:
        sessao.close()
