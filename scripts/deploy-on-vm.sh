#!/usr/bin/env bash
# Script exécuté SUR LA VM par "az vm run-command" depuis GitHub Actions.
# Les variables IMAGE_REF, COMPOSE_B64, GH_USER et GH_TOKEN sont ajoutées
# en tête de ce script par le workflow avant l'envoi.
set -eu

APP_DIR=/opt/cloudnotes
cd "$APP_DIR"

# 0) Attendre que cloud-init ait fini d'installer Docker (premier déploiement)
for i in $(seq 1 60); do
  [ -f "$APP_DIR/.bootstrap-done" ] && command -v docker >/dev/null && break
  echo "Attente de l'installation de Docker... ($i)"
  sleep 10
done

# 1) Écrire le compose.yaml envoyé par le pipeline
echo "$COMPOSE_B64" | base64 -d > compose.yaml

# 2) Indiquer quelle version de l'image utiliser (sans toucher au mot de passe)
grep -v '^WEB_IMAGE=' .env > .env.tmp || true
echo "WEB_IMAGE=$IMAGE_REF" >> .env.tmp
mv .env.tmp .env
chmod 600 .env

# 3) Se connecter au registre GHCR (jeton temporaire, expire après le job)
echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin

# 4) Télécharger la nouvelle image et redémarrer seulement ce qui a changé.
#    Le volume "pgdata" n'est PAS supprimé => les notes sont conservées.
docker compose pull web
docker compose up -d --no-build --remove-orphans

docker logout ghcr.io
docker image prune -f

# 5) Vérification locale sur la VM
for i in $(seq 1 30); do
  if curl -fs http://localhost/health >/dev/null; then
    echo "DEPLOY_OK $IMAGE_REF"
    docker compose ps
    exit 0
  fi
  sleep 3
done

echo "DEPLOY_FAILED"
docker compose ps
docker compose logs --tail=50 web
exit 1
