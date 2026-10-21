import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

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
def historico(usuario_id: uuid.UUID, limite: int = 50, sessao: Session = Depends(obter_sessao)):
    """Histórico do usuário, da avaliação mais recente para a mais antiga."""
    if sessao.get(Usuario, usuario_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuário não encontrado")
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
def apagar(usuario_id: uuid.UUID, sessao: Session = Depends(obter_sessao)):
    """Apaga o usuário e todas as avaliações dele (direito de exclusão, LGPD)."""
    usuario = sessao.get(Usuario, usuario_id)
    if usuario is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuário não encontrado")
    sessao.delete(usuario)
    sessao.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
