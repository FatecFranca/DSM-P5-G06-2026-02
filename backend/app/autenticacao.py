"""Contas de usuário: hash de senha (Argon2) e tokens de acesso (JWT).

O app continua funcionando sem conta (usuário anônimo identificado só pelo UUID).
Quando o usuário cria uma conta, as rotas com os dados dele passam a exigir o token.
"""

import threading
import time
import uuid
from collections import deque
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import obter_configuracoes
from .models import Usuario

ALGORITMO = "HS256"

_hasher = PasswordHasher()
# Quando o e-mail não existe, conferimos a senha contra este hash mesmo assim: a resposta
# demora o mesmo tempo e não revela quais e-mails estão cadastrados.
_HASH_FICTICIO = _hasher.hash("senha-ficticia-so-para-igualar-o-tempo")

_portador = HTTPBearer(auto_error=False, description="Token recebido em /auth/login ou /auth/cadastro")


def gerar_hash(senha: str) -> str:
    return _hasher.hash(senha)


def senha_confere(senha: str, hash_salvo: str | None) -> bool:
    try:
        _hasher.verify(hash_salvo or _HASH_FICTICIO, senha)
    except (VerificationError, InvalidHashError):
        return False
    return hash_salvo is not None


def precisa_novo_hash(hash_salvo: str) -> bool:
    """True quando os parâmetros do Argon2 mudaram desde que o hash foi gerado."""
    return _hasher.check_needs_rehash(hash_salvo)


class LimiteDeTentativas:
    """Bloqueia uma chave (o e-mail do login) depois de muitas falhas dentro de uma janela de tempo.

    Fica na memória de cada réplica da API: barra força bruta simples. Com várias réplicas,
    o limite efetivo é multiplicado pelo número delas (aceitável para o porte do projeto).
    """

    MAXIMO_CHAVES = 10_000

    def __init__(
        self,
        maximo: int = 5,
        janela_segundos: float = 15 * 60,
        relogio: Callable[[], float] = time.monotonic,
    ) -> None:
        self.maximo = maximo
        self.janela_segundos = janela_segundos
        self._relogio = relogio
        self._falhas: dict[str, deque[float]] = {}
        self._trava = threading.Lock()  # rotas síncronas rodam em várias threads

    def _recentes(self, chave: str) -> deque[float]:
        limite = self._relogio() - self.janela_segundos
        falhas = self._falhas.get(chave, deque())
        while falhas and falhas[0] <= limite:
            falhas.popleft()
        if not falhas:
            self._falhas.pop(chave, None)
        return falhas

    def bloqueado(self, chave: str) -> bool:
        with self._trava:
            return len(self._recentes(chave)) >= self.maximo

    def registrar_falha(self, chave: str) -> None:
        with self._trava:
            if len(self._falhas) >= self.MAXIMO_CHAVES:  # muitos e-mails diferentes: descarta os vencidos
                for antiga in list(self._falhas):
                    self._recentes(antiga)
            falhas = self._recentes(chave)
            falhas.append(self._relogio())
            self._falhas[chave] = falhas

    def limpar(self, chave: str | None = None) -> None:
        """Zera uma chave (login bem-sucedido) ou todas (testes)."""
        with self._trava:
            if chave is None:
                self._falhas.clear()
            else:
                self._falhas.pop(chave, None)


limite_de_login = LimiteDeTentativas()


def criar_token(usuario_id: uuid.UUID) -> tuple[str, datetime]:
    cfg = obter_configuracoes()
    agora = datetime.now(timezone.utc)
    expira_em = agora + timedelta(hours=cfg.jwt_expiracao_horas)
    token = jwt.encode(
        {"sub": str(usuario_id), "iat": agora, "exp": expira_em},
        cfg.jwt_segredo,
        algorithm=ALGORITMO,
    )
    return token, expira_em


def _nao_autenticado(mensagem: str) -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED, mensagem, headers={"WWW-Authenticate": "Bearer"}
    )


def ler_token(token: str) -> uuid.UUID:
    try:
        dados = jwt.decode(
            token,
            obter_configuracoes().jwt_segredo,
            algorithms=[ALGORITMO],
            options={"require": ["sub", "exp"]},
        )
        return uuid.UUID(dados["sub"])
    except (jwt.InvalidTokenError, ValueError) as erro:
        raise _nao_autenticado("Sessão inválida ou expirada. Faça login de novo.") from erro


def usuario_do_token(
    credenciais: HTTPAuthorizationCredentials | None = Security(_portador),
) -> uuid.UUID | None:
    """Id do usuário dono do token, ou None quando a requisição não tem token."""
    return None if credenciais is None else ler_token(credenciais.credentials)


def exigir_token(usuario_id: uuid.UUID | None = Depends(usuario_do_token)) -> uuid.UUID:
    if usuario_id is None:
        raise _nao_autenticado("Faça login para continuar.")
    return usuario_id


def obter_usuario_autorizado(
    sessao: Session, usuario_id: uuid.UUID, id_do_token: uuid.UUID | None
) -> Usuario:
    """Busca o usuário e confere o acesso.

    Usuário anônimo: basta o id (que só o aparelho conhece).
    Usuário com conta: exige o token do próprio dono.
    """
    usuario = sessao.get(Usuario, usuario_id)
    if usuario is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuário não encontrado")
    if usuario.tem_conta and id_do_token != usuario.id:
        if id_do_token is None:
            raise _nao_autenticado("Faça login para continuar.")
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Sem permissão para acessar estes dados")
    return usuario
