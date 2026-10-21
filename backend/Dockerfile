# Imagem da API. Construa a partir da RAIZ do repositório:
#   docker build -f backend/Dockerfile -t equilibra-api .
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MODEL_PATH=/app/modelo/modelo_burnout.joblib

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY ml/models/modelo_burnout.joblib ./modelo/modelo_burnout.joblib

# Usuário sem privilégios (boa prática de segurança)
RUN useradd --create-home api
USER api

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
