import uuid

from fastapi.testclient import TestClient

from app.main import app


def novo_usuario(cliente) -> str:
    uid = str(uuid.uuid4())
    r = cliente.post("/usuarios", json={"id": uid, "consentimento": True})
    assert r.status_code == 201
    return uid


def test_saude_sem_chave():
    r = TestClient(app).get("/saude")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_rotas_exigem_chave(respostas):
    r = TestClient(app).post("/predicoes", json={"usuario_id": str(uuid.uuid4()), "respostas": respostas})
    assert r.status_code == 401


def test_consentimento_obrigatorio(cliente):
    r = cliente.post("/usuarios", json={"id": str(uuid.uuid4()), "consentimento": False})
    assert r.status_code == 422


def test_registro_idempotente(cliente):
    uid = novo_usuario(cliente)
    r = cliente.post("/usuarios", json={"id": uid, "consentimento": True})
    assert r.status_code == 201


def test_predicao_retorna_json_completo(cliente, respostas):
    uid = novo_usuario(cliente)
    r = cliente.post("/predicoes", json={"usuario_id": uid, "respostas": respostas})
    assert r.status_code == 201
    corpo = r.json()
    assert corpo["nivel_risco"] in {"baixo", "medio", "alto"}
    assert abs(sum(corpo["probabilidades"].values()) - 1) < 0.01
    assert corpo["orientacoes"]
    assert corpo["aviso"]
    assert (corpo["apoio"] is not None) == (corpo["nivel_risco"] == "alto")


def test_perfil_extremo_tem_risco_alto(cliente, respostas):
    uid = novo_usuario(cliente)
    r = cliente.post("/predicoes", json={"usuario_id": uid, "respostas": respostas})
    assert r.json()["nivel_risco"] == "alto"


def test_predicao_sem_usuario(cliente, respostas):
    r = cliente.post("/predicoes", json={"usuario_id": str(uuid.uuid4()), "respostas": respostas})
    assert r.status_code == 404


def test_validacao_de_faixas(cliente, respostas):
    uid = novo_usuario(cliente)
    respostas["ansiedade_provas"] = 15
    r = cliente.post("/predicoes", json={"usuario_id": uid, "respostas": respostas})
    assert r.status_code == 422


def test_historico_e_exclusao(cliente, respostas):
    uid = novo_usuario(cliente)
    for _ in range(3):
        cliente.post("/predicoes", json={"usuario_id": uid, "respostas": respostas})

    hist = cliente.get(f"/usuarios/{uid}/avaliacoes").json()
    assert len(hist) == 3
    assert hist[0]["id"] > hist[-1]["id"]

    assert cliente.delete(f"/usuarios/{uid}").status_code == 204
    assert cliente.get(f"/usuarios/{uid}/avaliacoes").status_code == 404
