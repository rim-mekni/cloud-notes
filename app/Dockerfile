# Image de l'application web
FROM python:3.12-slim

WORKDIR /app

# Installer les dépendances d'abord (meilleur cache Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY app.py .
COPY templates ./templates

EXPOSE 8000

# gunicorn = serveur web de production pour Flask
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:create_app()"]
