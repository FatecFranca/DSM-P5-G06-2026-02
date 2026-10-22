import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..autenticacao import (
    criar_token,
    exigir_token,
    gerar_hash,
    limite_de_login,
    precisa_novo_hash,
    senha_confere,
)
from ..database import obter_sessao
from ..models import Avaliacao, Usuario
from ..schemas import CadastroEntrada, ContaResposta, LoginEntrada, TokenResposta

router = APIRouter(prefix="/auth", tags=["Contas"])


def _resposta_com_token(usuario: Usuario) -> TokenResposta:
    token, expira_em = criar_token(usuario.id)
    return TokenResposta(token=token, expira_em=expira_em, usuario_id=usuario.id, email=usuario.email)


@router.post("/cadastro", response_model=TokenResposta, status_code=status.HTTP_201_CREATED)
def cadastrar(dados: CadastroEntrada, sessao: Session = Depends(obter_sessao)):
    """Transforma o usuário anônimo do aparelho numa conta. O histórico continua o mesmo."""
    usuario = sessao.get(Usuario, dados.usuario_id)
    if usuario is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, "Usuário não encontrado. Aceite o termo em POST /usuarios antes."
        )
    if usuario.tem_conta:
        raise HTTPException(status.HTTP_409_CONFLICT, "Este aparelho já tem uma conta. Faça login.")
    if sessao.scalar(select(Usuario.id).where(Usuario.email == dados.email)) is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Este e-mail já está cadastrado. Faça login.")

    # consentimento_em guarda o primeiro aceite (LGPD) e não é sobrescrito;
    # o aceite do termo da conta fica registrado em conta_criada_em + versao_termo.
    usuario.email = dados.email
    usuario.senha_hash = gerar_hash(dados.senha)
    usuario.conta_criada_em = datetime.now(timezone.utc)
    usuario.versao_termo = dados.versao_termo
    try:
        sessao.commit()
    except IntegrityError as erro:  # dois cadastros simultâneos com o mesmo e-mail
        sessao.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Este e-mail já está cadastrado.") from erro
    return _resposta_com_token(usuario)


@router.post("/login", response_model=TokenResposta)
def entrar(dados: LoginEntrada, sessao: Session = Depends(obter_sessao)):
    """Confere e-mail e senha e devolve um token de acesso."""
    if limite_de_login.bloqueado(dados.email):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Muitas tentativas de login. Espere alguns minutos e tente de novo.",
        )
    conta = sessao.scalar(select(Usuario).where(Usuario.email == dados.email))
    # Sem conta, a senha é conferida contra um hash fictício (mesmo tempo de resposta)
    # e a mensagem é a mesma: não revela se o e-mail existe.
    if not senha_confere(dados.senha, conta.senha_hash if conta else None):
        limite_de_login.registrar_falha(dados.email)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-mail ou senha incorretos.")
    limite_de_login.limpar(dados.email)

    if precisa_novo_hash(conta.senha_hash):
        conta.senha_hash = gerar_hash(dados.senha)
    if dados.usuario_id_anonimo is not None:
        _unir_historico_anonimo(sessao, dados.usuario_id_anonimo, conta)
    sessao.commit()
    return _resposta_com_token(conta)


@router.get("/me", response_model=ContaResposta)
def minha_conta(usuario_id: uuid.UUID = Depends(exigir_token), sessao: Session = Depends(obter_sessao)):
    """Dados da conta dona do token."""
    usuario = sessao.get(Usuario, usuario_id)
    if usuario is None or not usuario.tem_conta:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Conta não encontrada. Faça login de novo.")
    return ContaResposta(
        usuario_id=usuario.id, email=usuario.email, conta_criada_em=usuario.conta_criada_em
    )


def _unir_historico_anonimo(sessao: Session, anonimo_id: uuid.UUID, conta: Usuario) -> None:
    """Passa as avaliações do usuário anônimo para a conta e apaga o anônimo.

    Só vale para usuário sem conta: o histórico de outra conta nunca é tocado.
    """
    anonimo = sessao.get(Usuario, anonimo_id)
    if anonimo is None or anonimo.tem_conta or anonimo.id == conta.id:
        return
    sessao.execute(
        update(Avaliacao).where(Avaliacao.usuario_id == anonimo.id).values(usuario_id=conta.id)
    )
    sessao.delete(anonimo)  # as avaliações já foram movidas; nada é apagado em cascata
