# Equilibra

Aplicativo mobile que estima o **risco de burnout** de estudantes (baixo, médio ou alto) a partir dos hábitos de estudo e do uso de IA generativa.

Projeto Interdisciplinar, 5º semestre de Desenvolvimento de Software Multiplataforma (DSM), Fatec Franca.
Causa social: ODS 3 (Saúde e Bem-Estar) e ODS 4 (Educação de Qualidade).

> Autoavaliação educativa, **não** diagnóstico.

**Integrantes:** Gabriel Antônio Ferrarez Oliveira · _(segundo integrante)_
**Vídeo de demonstração:** _(link do YouTube na entrega)_

## Arquitetura

```
App Flutter ──HTTPS/JSON──▶ API FastAPI + modelo de ML ──SQL──▶ PostgreSQL
 (celular)                   (Azure Container Apps)            (rede privada, sem IP público)
```

Só a API acessa o banco. O deploy é automatizado pelo GitHub Actions.

## Estrutura do repositório

| Pasta | Conteúdo |
| --- | --- |
| `ml/` | Base de dados do Kaggle, preparo, treino e o modelo salvo (`models/modelo_burnout.joblib`) |
| `backend/` | API REST em FastAPI: cadastro com consentimento, predição, histórico e exclusão de dados |
| `database/` | `schema.sql`: tabelas `usuarios` e `avaliacoes` do PostgreSQL |
| `mobile/` | App Flutter: consentimento, questionário, resultado e histórico com gráfico |
| `.github/workflows/` | CI: testes da API, build da imagem Docker, análise e testes do Flutter |

## Como rodar localmente

### 1. Modelo de ML (opcional: o modelo treinado já está no repositório)

```bash
cd ml
pip install -r requirements.txt
python src/preparar_base.py
python src/treinar_modelo.py
```

### 2. Banco + API com Docker

```bash
cp .env.example .env
docker compose up --build
```

A documentação da API (Swagger) fica em http://localhost:8000/docs.

### 2b. API sem Docker (com um PostgreSQL já instalado)

```bash
psql -U postgres -c "CREATE USER equilibra PASSWORD 'equilibra';" -c "CREATE DATABASE equilibra OWNER equilibra;"
psql -U equilibra -d equilibra -f database/schema.sql
cd backend
pip install -r requirements-dev.txt
pytest -q                       # testes (usam SQLite, não precisam do PostgreSQL)
uvicorn app.main:app --reload
```

### 3. App Flutter

Veja [`mobile/README.md`](mobile/README.md).

## Endpoints

| Método | Rota | O que faz |
| --- | --- | --- |
| GET | `/saude` | Verificação de vida (sem chave) |
| POST | `/usuarios` | Registra o aceite do termo para o id anônimo do aparelho |
| POST | `/predicoes` | Classifica o risco e salva a avaliação |
| GET | `/usuarios/{id}/avaliacoes` | Histórico, do mais recente ao mais antigo |
| DELETE | `/usuarios/{id}` | Apaga o usuário e todas as avaliações (LGPD) |

Todas as rotas, exceto `/saude`, exigem o cabeçalho `X-API-Key`.

## Sprints

| Sprint | Período | Entrega | Situação |
| --- | --- | --- | --- |
| 1 | 12/10 a 18/10 | Base de dados e modelo | Concluída |
| 2 | 19/10 a 25/10 | API REST + banco | Esqueleto pronto |
| 3 | 26/10 a 01/11 | Azure + CI/CD | CI pronto; falta o deploy |
| 4 | 02/11 a 08/11 | App Flutter | Esqueleto pronto |
| 5 | 09/11 a 15/11 | Notificações, áudio, documentação | A fazer |

Entrega final: 18/11/2026.

## Base de dados

[Impact of AI on Students](https://www.kaggle.com/datasets/laveshjadon/ai-impact-on-students), licença CC0. Detalhes, decisões e resultados em [`ml/README.md`](ml/README.md).
