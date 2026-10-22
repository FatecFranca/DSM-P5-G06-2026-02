import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..autenticacao import obter_usuario_autorizado, usuario_do_token
from ..database import obter_sessao
from ..models import Avaliacao, Usuario
from ..schemas import AvaliacaoResumo, Probabilidades, UsuarioCriar, UsuarioResposta

router = APIRouter(prefix="/usuarios", tags=["Usuários"])


@router.post("", response_model=UsuarioResposta, status_code=status.HTTP_201_CREATED)
def registrar(dados: UsuarioCriar, sessao: Session = Depends(obter_sessao)):
    """Registra o aceite do termo (LGPD). Idempotente: repetir não duplica."""
    usuario = sessao.get(Usuario, dados.id)
    if usuario is None:
        usuario = Usuario(
            id=dados.id,
            consentimento_em=datetime.now(timezone.utc),
            versao_termo=dados.versao_termo,
        )
        sessao.add(usuario)
        sessao.commit()
    return usuario


@router.get("/{usuario_id}/avaliacoes", response_model=list[AvaliacaoResumo])
def historico(
    usuario_id: uuid.UUID,
    limite: int = Query(50, ge=1),
    sessao: Session = Depends(obter_sessao),
    id_do_token: uuid.UUID | None = Depends(usuario_do_token),
):
    """Histórico do usuário, da avaliação mais recente para a mais antiga.

    Se o usuário tem conta, exige o token dele.
    """
    obter_usuario_autorizado(sessao, usuario_id, id_do_token)
    linhas = sessao.scalars(
        select(Avaliacao)
        .where(Avaliacao.usuario_id == usuario_id)
        .order_by(Avaliacao.criado_em.desc(), Avaliacao.id.desc())
        .limit(min(limite, 200))
    )
    return [
        AvaliacaoResumo(
            id=a.id,
            criado_em=a.criado_em,
            nivel_risco=a.nivel_risco,
            probabilidades=Probabilidades(
                baixo=float(a.prob_baixo), medio=float(a.prob_medio), alto=float(a.prob_alto)
            ),
            horas_ia_semana=float(a.horas_ia_semana),
            ansiedade_provas=a.ansiedade_provas,
        )
        for a in linhas
    ]


@router.delete("/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
def apagar(
    usuario_id: uuid.UUID,
    sessao: Session = Depends(obter_sessao),
    id_do_token: uuid.UUID | None = Depends(usuario_do_token),
):
    """Apaga o usuário, a conta (se houver) e todas as avaliações (direito de exclusão, LGPD)."""
    usuario = obter_usuario_autorizado(sessao, usuario_id, id_do_token)
    sessao.delete(usuario)
    sessao.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
