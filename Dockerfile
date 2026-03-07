# Estágio 1: Builder (para instalar dependências) a partir de uma imagem python comum
FROM python:3.9-slim AS builder

# Criamos uma pasta de trabalho dentro do container
WORKDIR /app

# Copia o arquivo de dependências 
COPY app/requirements.txt .

# Instalamos as dependências em uma pasta local usando -t (target)
RUN pip install --no-cache-dir -r requirements.txt -t /app/libs

# Estágio 2: Imagem Final (Distroless)
# Usamos debian11 para garantir compatibilidade binária com o python:3.9-slim
FROM gcr.io/distroless/python3-debian11

# Criamos uma pasta de trabalho dentro do container de novo
WORKDIR /app

# Copiamos as bibliotecas instaladas no estágio anterior
COPY --from=builder /app/libs /app/libs

# Copiamos o código da aplicação
COPY app .

# Definimos para o Python onde ele deve procurar as bibliotecas e modulos do import
ENV PYTHONPATH=/app/libs
EXPOSE 8000
# Executamos o gunicorn como módulo (-m) pois distroless não tem shell para rodar scripts binários
CMD ["-m", "gunicorn", "--bind", "0.0.0.0:8000", "--log-level", "debug", "api:app"]
