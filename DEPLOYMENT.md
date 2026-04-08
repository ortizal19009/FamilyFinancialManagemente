# Despliegue con Docker

## Servicios incluidos

- `db`: PostgreSQL 16
- `backend`: Flask + Uvicorn
- `frontend`: Angular compilado y servido con Nginx

## Archivos clave

- [docker-compose.yml](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/docker-compose.yml)
- [backend/Dockerfile](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/backend/Dockerfile)
- [frontend/Dockerfile](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/frontend/Dockerfile)
- [frontend/nginx.conf](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/frontend/nginx.conf)

## Levantar el proyecto

Desde la raíz del repo:

```bash
docker compose up --build -d
```

## URLs

- Frontend: `http://TU_SERVIDOR:8080`
- Backend health: `http://TU_SERVIDOR:5000/health`

El frontend ya reenvía `/api` al backend internamente con Nginx.

## Base de datos

La primera vez que se cree el volumen de PostgreSQL, Docker ejecutará [database.sql](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/database.sql).

Si ya tenías una base existente y agregaste tablas nuevas como `investments` o `small_debts`, debes ejecutar esos `CREATE TABLE` manualmente o recrear el volumen.

## Comandos útiles

Ver logs:

```bash
docker compose logs -f
```

Reiniciar servicios:

```bash
docker compose restart
```

Bajar contenedores:

```bash
docker compose down
```

Borrar también la base persistida:

```bash
docker compose down -v
```

## Despliegue recomendado en servidor

1. Instala Docker y Docker Compose Plugin.
2. Sube este repositorio al servidor.
3. Ajusta secretos reales en `docker-compose.yml`.
4. Ejecuta `docker compose up --build -d`.
5. Abre el puerto `8080` o coloca un reverse proxy delante.

## Despliegue hibrido: Nginx para frontend y Docker para backend

Si prefieres dejar el frontend servido por el Nginx del servidor y usar Docker solo para el backend:

1. Instala en el servidor: `docker`, `docker compose`, `nginx`, `node`, `npm`, `rsync`.
2. Sube el repositorio al servidor.
3. Ejecuta:

```bash
chmod +x ./deploy-server.sh
./deploy-server.sh
```

El script:

- compila Angular
- publica el frontend en `/var/www/family-finance`
- instala una configuracion de Nginx
- recarga Nginx
- reconstruye y levanta solo el servicio `backend` con Docker

Variables utiles antes de correrlo:

```bash
export APP_DOMAIN=midominio.com
export FRONTEND_TARGET_DIR=/var/www/family-finance
export BACKEND_HOST=127.0.0.1
export BACKEND_PORT=5000
./deploy-server.sh
```

Archivos relacionados:

- [deploy-server.sh](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/deploy-server.sh)
- [deploy/nginx.family-finance.conf.template](/c:/Users/Alexis%20Ortiz/Documents/trae_projects/FamilyFinancialManagemente/deploy/nginx.family-finance.conf.template)

## Notas

- El backend guarda adjuntos en un volumen Docker llamado `backend_uploads`.
- Si quieres usar dominio con HTTPS, lo ideal es poner Nginx Proxy Manager, Traefik o Nginx externo delante del puerto `8080`.
