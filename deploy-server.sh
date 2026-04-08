#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
FRONTEND_DIST_DIR="$FRONTEND_DIR/dist/frontend/browser"

APP_NAME="${APP_NAME:-family-finance}"
APP_DOMAIN="${APP_DOMAIN:-_}"
FRONTEND_TARGET_DIR="${FRONTEND_TARGET_DIR:-/var/www/$APP_NAME}"
NGINX_SITES_AVAILABLE_DIR="${NGINX_SITES_AVAILABLE_DIR:-/etc/nginx/sites-available}"
NGINX_SITES_ENABLED_DIR="${NGINX_SITES_ENABLED_DIR:-/etc/nginx/sites-enabled}"
NGINX_CONF_NAME="${NGINX_CONF_NAME:-$APP_NAME.conf}"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-5000}"
DEPLOY_FRONTEND="${DEPLOY_FRONTEND:-1}"
DEPLOY_BACKEND="${DEPLOY_BACKEND:-1}"
INSTALL_NGINX_CONF="${INSTALL_NGINX_CONF:-1}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $1" >&2
    exit 1
  fi
}

ensure_sudo() {
  if [[ "$(id -u)" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

deploy_frontend() {
  require_command npm
  require_command rsync

  log "Compilando frontend Angular"
  cd "$FRONTEND_DIR"
  npm ci
  npm run build

  if [[ ! -d "$FRONTEND_DIST_DIR" ]]; then
    echo "No se encontro el build del frontend en: $FRONTEND_DIST_DIR" >&2
    exit 1
  fi

  log "Publicando frontend en $FRONTEND_TARGET_DIR"
  ensure_sudo mkdir -p "$FRONTEND_TARGET_DIR"
  ensure_sudo rsync -av --delete "$FRONTEND_DIST_DIR"/ "$FRONTEND_TARGET_DIR"/
}

install_nginx_conf() {
  require_command nginx

  local temp_conf
  temp_conf="$(mktemp)"

  sed \
    -e "s|__SERVER_NAME__|$APP_DOMAIN|g" \
    -e "s|__FRONTEND_ROOT__|$FRONTEND_TARGET_DIR|g" \
    -e "s|__BACKEND_HOST__|$BACKEND_HOST|g" \
    -e "s|__BACKEND_PORT__|$BACKEND_PORT|g" \
    "$ROOT_DIR/deploy/nginx.family-finance.conf.template" > "$temp_conf"

  log "Instalando configuracion de Nginx"
  ensure_sudo mkdir -p "$NGINX_SITES_AVAILABLE_DIR" "$NGINX_SITES_ENABLED_DIR"
  ensure_sudo cp "$temp_conf" "$NGINX_SITES_AVAILABLE_DIR/$NGINX_CONF_NAME"
  ensure_sudo ln -sfn \
    "$NGINX_SITES_AVAILABLE_DIR/$NGINX_CONF_NAME" \
    "$NGINX_SITES_ENABLED_DIR/$NGINX_CONF_NAME"
  rm -f "$temp_conf"

  log "Validando y recargando Nginx"
  ensure_sudo nginx -t
  ensure_sudo systemctl reload nginx
}

deploy_backend() {
  require_command docker

  log "Actualizando backend con Docker"
  cd "$ROOT_DIR"
  docker compose up -d --build backend
}

main() {
  log "Iniciando despliegue en servidor"

  if [[ "$DEPLOY_FRONTEND" == "1" ]]; then
    deploy_frontend
  fi

  if [[ "$INSTALL_NGINX_CONF" == "1" ]]; then
    install_nginx_conf
  fi

  if [[ "$DEPLOY_BACKEND" == "1" ]]; then
    deploy_backend
  fi

  log "Despliegue completado"
  echo "Frontend: $FRONTEND_TARGET_DIR"
  echo "Nginx conf: $NGINX_SITES_AVAILABLE_DIR/$NGINX_CONF_NAME"
  echo "Backend Docker: ffm-backend"
}

main "$@"
