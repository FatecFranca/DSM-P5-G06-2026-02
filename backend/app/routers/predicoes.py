import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from .. import classificador
from ..autenticacao import obter_usuario_autorizado, usuario_do_token
from ..database import obter_sessao
from ..models import Avaliacao
from ..schemas import PredicaoEntrada, PredicaoResposta, Probabilidades

router = APIRouter(prefix="/predicoes", tags=["Predições"])


@router.post("", response_model=PredicaoResposta, status_code=status.HTTP_201_CREATED)
def prever(
    dados: PredicaoEntrada,
    sessao: Session = Depends(obter_sessao),
    id_do_token: uuid.UUID | None = Depends(usuario_do_token),
):
    """Classifica o risco de burnout e salva a avaliação no histórico.

    Exige o consentimento (POST /usuarios) antes. Se o usuário tem conta, exige o token dele.
    """
    obter_usuario_autorizado(sessao, dados.usuario_id, id_do_token)

    nivel, probs = classificador.classificar(dados.respostas)
    avaliacao = Avaliacao(
        usuario_id=dados.usuario_id,
        **dados.respostas.model_dump(),
        nivel_risco=nivel,
        prob_baixo=probs["baixo"],
        prob_medio=probs["medio"],
        prob_alto=probs["alto"],
        versao_modelo=classificador.versao_modelo(),
    )
    sessao.add(avaliacao)
    sessao.commit()
    sessao.refresh(avaliacao)

    return PredicaoResposta(
        avaliacao_id=avaliacao.id,
        nivel_risco=nivel,
        probabilidades=Probabilidades(**probs),
        orientacoes=classificador.ORIENTACOES[nivel],
        apoio=classificador.APOIO if nivel == "alto" else None,
        aviso=classificador.AVISO,
        versao_modelo=avaliacao.versao_modelo,
        criado_em=avaliacao.criado_em,
    )
