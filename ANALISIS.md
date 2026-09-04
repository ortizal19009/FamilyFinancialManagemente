# Análisis del Sistema — Family Financial Management

> Documento de análisis técnico generado a partir de la inspección del repositorio.
> Fecha: septiembre 2026.

---

## Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Arquitectura](#2-arquitectura)
3. [Estructura del Repositorio](#3-estructura-del-repositorio)
4. [Base de Datos](#4-base-de-datos)
5. [Backend](#5-backend)
6. [Frontend Web (Angular)](#6-frontend-web-angular)
7. [App Móvil (Flutter)](#7-app-móvil-flutter)
8. [Despliegue](#8-despliegue)
9. [Lógica de Negocio Clave](#9-lógica-de-negocio-clave)
10. [Roles y Permisos](#10-roles-y-permisos)
11. [Fortalezas](#11-fortalezas)
12. [Deuda Técnica y Riesgos](#12-deuda-técnica-y-riesgos)
13. [Recomendaciones y Próximos Pasos](#13-recomendaciones-y-próximos-pasos)

---

## 1. Visión General

Aplicación integral para el control de las finanzas familiares. Permite gestionar:

- Usuarios e integrantes de la familia (relaciones entre miembros).
- Entidades financieras (bancos/cooperativas), cuentas bancarias y tarjetas.
- Préstamos, activos (bienes), inversiones e ingresos.
- Gastos diarios con métodos de pago y comprobantes (PDF/imagen con análisis automático).
- Planificación mensual por categorías y control deuda/deudores deudas pequeñas.
- Dashboard con KPIs y módulo de reportes (PDF/XML).
- App móvil con sincronización **offline-first**.

Está compuesto por **tres clientes contra un único backend**:

| Componente | Tecnología | Estado |
|---|---|---|
| Backend API | Python Flask + SQLAlchemy (PostgreSQL) | Completo |
| Frontend Web (PWA) | Angular 21 + Bootstrap 5 | Completo |
| App Móvil | Flutter (Material 3) | Código completo; requiere `flutter create` para compilar |

---

## 2. Arquitectura

```
                    ┌─────────────────────────────┐
                    │        PostgreSQL           │
                    │       family_finance        │
                    └──────────────┬──────────────┘
                                   │ SQLAlchemy (ORM)
                    ┌──────────────▼──────────────┐
                    │    Backend Flask + Uvicorn   │
                    │   API REST /api/*  (JWT)     │
                    │  Compartido por 3 clientes   │
                    └──────────────┬──────────────┘
                        ┌──────────┼──────────┐
        ┌───────────────▼───┐  ┌──▼─────────┐  ┌▼──────────────────┐
        │ Angular Frontend  │  │  Flutter    │  │  Reportes/recibos  │
        │ (Browser + PWA)   │  │  Mobile     │  │  PDF, XML, OCR     │
        └───────────────────┘  └────────────┘  └───────────────────┘
```

### Decisiones de arquitectura destacadas

- **Un solo backend, tres clientes**: La app móvil y la web consumen exactamente los mismos endpoints `/api/*`.
- **Offline-first en móvil**: El cliente Flutter persiste localmente en SQLite, encola operaciones y sincroniza contra el backend al recuperar conectividad.
- **Autenticación JWT**: Tokens de acceso de 1 hora, sin refresh token.
- **Roles**: `admin` (ve todo) y `member` (solo sus registros), con excepción de cuentas bancarias y activos que son globales.

---

## 3. Estructura del Repositorio

```
FamilyFinancialManagemente/
├── backend/                  API REST (Flask)
│   ├── app.py                Fábrica de la app, blueprints, logging, healthcheck
│   ├── config.py             Configuración vía variables de entorno
│   ├── models.py             14 modelos SQLAlchemy
│   ├── requirements.txt      11 dependencias pinneadas
│   ├── Dockerfile            Imagen multi-etapa (Python 3.12-slim)
│   ├── routes/               11 blueprints
│   └── data/                 Manifest de comprobantes (JSON)
├── frontend/                 Angular PWA
│   ├── src/app/
│   │   ├── components/       Login, Register, Dashboard, Banks, CardsLoans,
│   │   │                     Expenses, Planning, AssetsIncome, Debtors,
│   │   │                     FamilyMembers, Investments, AdminUsers
│   │   ├── guards/           auth.guard, guest.guard
│   │   ├── interceptors/     auth, timing, zone
│   │   └── services/         api.service, auth.service
│   ├── Dockerfile + nginx.conf
│   └── proxy.conf.mjs        Proxy de desarrollo /api -> 127.0.0.1:5000
├── mobile/                   App Flutter
│   ├── lib/
│   │   ├── core/             config, network, offline, storage, theme, widgets
│   │   └── features/         auth, banks, cards, expenses, dashboard, family,
│   │                         assets, debtors, investments, planning, settings,
│   │                         admin, home
│   └── pubspec.yaml
├── deploy/                   Plantilla Nginx para servidor
├── database.sql              Esquema DDL de PostgreSQL (14 tablas + seed)
├── docker-compose.yml        Orquestación Docker
├── deploy-server.sh          Despliegue híbrido (Nginx + Docker backend)
├── build-mobile-apk.ps1      Script de compilación APK
├── start-backend.ps1         Arranque local del backend (Uvicorn)
├── start-frontend.ps1        Arranque local del frontend (npm start)
├── test_db.py / test_sqlalchemy.py   Utilidades de diagnóstico de conexión
├── PLANNING.md               Planificación original / hoja de ruta
├── DEPLOYMENT.md             Guía de despliegue
└── README.md                 Guía de ejecución y manual de usuario
```

---

## 4. Base de Datos

Motor: **PostgreSQL** (15 tablas + seed de categorías). Esquema definido en `database.sql` y replicado en `backend/models.py`.

### Tablas

| Tabla | Propósito | Notas |
|---|---|---|
| `users` | Cuentas de acceso | rol `admin`/`member`, password con Bcrypt |
| `family_members` | Integrantes | 1:1 con `users` (opcional), nombre + parentesco |
| `family_relationships` | Relaciones entre integrantes | par único `(source, target)`, relación dirigida |
| `banks` | Bancos/cooperativas | |
| `bank_accounts` | Cuentas bancarias | saldo `current_balance`; en SQL el modelo no declara `user_id` pero SQL sí lo tiene |
| `cards` | Tarjetas débito/crédito | límite, deuda actual, saldo disponible |
| `loans` | Préstamos | cuotas totales/pendientes, tasa, mensualidad |
| `assets` | Bienes/activos | valor para patrimonio |
| `investments` | Inversiones | institución, tipo, montos, estado |
| `categories` | Categorías de gasto | seed de 8 categorías |
| `monthly_planning` | Presupuesto mensual por categoría | clave `(category, month, year)` |
| `income` | Ingresos/sueldos | destino `cash` o `bank_account` |
| `debtors` | Cuentas por cobrar | estado `pendiente`/`pagado` |
| `small_debts` | Deudas pequeñas (debemos) | prestamista, montos, plazos |
| `expenses` | Gastos diarios | método de pago, tarjeta/cuenta vinculada |

### Categorías por defecto (seed)

Alimentos, Medicina, Vivienda, Transporte, Educación, Entretenimiento, Servicios Básicos, Otros.

### Migraciones

- Flask-Migrate está inicializado pero **no se usa con versiones**.
- `app.py` aplica **migraciones manuales** al arranque (`ensure_family_schema`, `ensure_income_schema`, `ensure_cards_schema`) con `ALTER TABLE` condicional según columnas existentes.
- detección de tablas nuevas como `investments`/`small_debts` se hace con `HasTable`/`inspect`.

### Divergencias modelo vs. SQL

- `BankAccount` en SQL tiene `user_id`; el modelo ORM **no** lo declara.
- `Asset` en SQL tiene `user_id`; el modelo ORM **no** lo declara.
- La serialización de `users` expone `created_at` como objeto (no ISO), lo que puede causar inconsistencias en los clientes.

---

## 5. Backend

### Stack y dependencias

`Flask 3.0.0`, `Flask-SQLAlchemy 3.1.1`, `Flask-JWT-Extended 4.5.3`, `Flask-Migrate 4.0.5`, `Flask-CORS 4.0.0`, `psycopg2-binary`, `bcrypt`, `pypdf` (comprobantes PDF), `uvicorn` + `a2wsgi` (ASGI), `python-dotenv`. Opcional: `Pillow` + `pytesseract` (OCR de imágenes).

### Modelos (14) — `backend/models.py`

`User`, `FamilyMember`, `FamilyRelationship`, `Bank`, `BankAccount`, `Card`, `Loan`, `Asset`, `Investment`, `Category`, `MonthlyPlanning`, `Income`, `Debtor`, `SmallDebt`, `Expense`.

- Contraseñas con `bcrypt` (`set_password` / `check_password`).
- Relaciones: cuentas → banco, tarjetas → banco/cuenta/usuario, gastos → usuario/categoría/tarjeta/cuenta.

### Blueprints y endpoints

Prefijos registrados en `app.py`:

| Blueprint | Prefijo | Endpoints principales |
|---|---|---|
| `auth` | `/api/auth` | register, login, users (GET/POST admin), me, family-link-options |
| `banks` | `/api/banks` | CRUD bancos, CRUD cuentas (`/accounts`) |
| `expenses` | `/api/expenses` | CRUD gastos (agrupados), categorías, `analyze-receipt`, `{id}/receipt` |
| `cards_loans` | `/api/cards_loans` | CRUD tarjetas (`/cards`), CRUD préstamos (`/loans`) |
| `assets_income` | `/api/assets_income` | CRUD activos (`/assets`), CRUD ingresos (`/income`) |
| `planning` | `/api/planning` | consulta/save plan mensual por categoría |
| `debtors` | `/api/debtors` | CRUD deudores (`/`), CRUD deudas pequeñas (`/small-debts`) |
| `family` | `/api/family` | CRUD miembros + relaciones con inversa automática |
| `dashboard` | `/api/dashboard` | `/summary` (KPIs + últimos 5 gastos) |
| `investments` | `/api/investments` | CRUD inversiones (con profit/loss calculado) |
| `reports` | `/api/reports` | `/export` (summary, movements, accounts, expenses, planning en PDF/XML) |

Total de operaciones expuestas: ~40 endpoints.

### Seguridad

- Todos los endpoints de datos exigen `@jwt_required()`.
- Roles verificados por `user.role != 'admin'` para edición/borrado de registros ajenos.
- Payload sensible sanitizado en logs (`**` para password/tokens).
- Callbacks personalizados de JWT para token inválido/expirado/ausente.
- Admin por defecto auto-creado al arranque (`DEFAULT_ADMIN_*`).
- CORS habilitado globalmente para `/api/*`.

### Características notables del backend

- **Gastos agrupados**: `expenses.py` agrupa registros por clave (`user + fecha + método + descripción + created_at`) para representar "un comprobante con N categorías".
- **Efecto automático en saldos**: al crear/editar/borrar un gasto, actualiza deuda de tarjeta de crédito o saldo de cuenta/tarjeta de débito (con reversión `sign=-1`).
- **Análisis de comprobantes**: extrae texto de PDF (pypdf) o imagen (tesseract, opcional), detecta total, fecha, comercio y sugiere hasta 3 categorías mediante keywords.
- **Reportes**: generación *manual* de PDF (escritor PDF mínimo, sin librería externa) y XML estructurado.
- **Fusiones (merge)**: al crear duplicados de cuentas, categorías o planes, actualiza el existente y redirige IDs.
- **Logging de request/response**: tiempo de respuesta y preview de errores para trazas.

### Limitaciones / detalles

- `create_asset` no persiste `user_id` (el modelo no lo tiene aunque SQL lo permita).
- `reports.py` usa queries globales sin filtrar por usuario en varios conteos (bancos, cuentas, activos, planes), incluso para miembros.
- No hay paginación real en listados.
- Errores de DB devueltos al cliente en algunos casos (falta captura global de `SQLAlchemyError`).

---

## 6. Frontend Web (Angular)

### Stack

- **Angular 21** (standalone, sin NgModules), TypeScript 5.9, `rxjs`.
- **Bootstrap 5.3** + `bootstrap-icons` (sin librerías de gráficos).
- **PWA** con `@angular/service-worker` (`ngsw-config.json`, manifest, 8 iconos).
- `proxy.conf.mjs` para desarrollo (`/api` → `127.0.0.1:5000`).

### Rutas (14 + redirect)

| Ruta | Componente | Guard |
|---|---|---|
| `/login`, `/register` | Login / Register | `guestGuard` |
| `/dashboard`, `/expenses`, `/banks`, `/planning`, `/debtors`, `/investments`, `/family`, `/admin/users` | componentes respectivos | `authGuard` |
| `/cards` + `/loans` | `CardsLoansComponent` (pestañas) | `authGuard` |
| `/assets` + `/income` | `AssetsIncomeComponent` (pestañas) | `authGuard` |
| `''` | → `/login` | — |

### Componentes

Todos standalone + template forms (`ngModel`), CRUD con patrón form único crear/editar, mensajes efímeros success/error, spinners de carga, confirmaciones con `window.confirm`.

| Componente | Funcionalidad |
|---|---|
| Login | Carrusel de imágenes, auth → localStorage → /dashboard |
| Register | Alta propia (rol member fijo) |
| Dashboard | 5 KPIs (saldo, deuda, gastos mes, patrimonio, inversiones), actividad reciente, **módulo de reportes PDF/XML** |
| Banks | CRUD bancos + cuentas (Ahorros/Corriente/Inversión, titular = miembro) |
| CardsLoans | Tarjetas (débito/crédito, cupo, barra de uso) y préstamos (cuotas, progreso) |
| Expenses | Gasto multi-categoría, 5 métodos de pago, **adjuntar y analizar comprobante**, listado agrupado |
| Planning | Presupuesto mensual, comparativo planeado vs real, barras de progreso (rojo si excede) |
| AssetsIncome | Inventario de bienes (valor total) + ingresos (destino cuenta/cash) |
| Debtors | Deudores (por cobrar) + deudas pequeñas (por pagar) |
| FamilyMembers | CRUD miembros, crea usuario vinculado si el correo no existe, genera contraseña temporal |
| Investments | CRUD inversiones, KPIs de capital, valor actual y rendimiento |
| AdminUsers | Solo admin: listar/crear usuarios |

### Servicios

- **`api.service.ts`**: URL base `/api`. Expone `Observable<any[]>` para cada módulo; `createExpense` usa `FormData` (`payload` JSON + archivo); reportes con `responseType: 'blob'`.
- **`auth.service.ts`**: signals (`currentUser`), login/register/logout, `isAuthenticated`, `isAdmin`, gestión de usuarios (admin).

### Guards e interceptors

- `authGuard` / `guestGuard`: protegen según sesión.
- `authInterceptor`: adjunta `Bearer` token, y en `401` (excepto login/register) hace logout. **Sin roleGuard** para `/admin/users`.
- `zoneInterceptor`: fuerza ejecución dentro de `ngZone` (cambio de detección).
- `timingInterceptor`: log de duración de peticiones.

### PWA

- SW solo en producción (`registerWhenStable`), prefetch de assets estáticos, sin `dataGroups` (la API no se cachea).
- Manifest genérico (nombre aún `frontend`).

### Observaciones del frontend

- Hash `251` UI 100% en español; `<html lang="en">` inconsistente.
- Elementos decorativos sin función: buscador de gastos y botón "Cargar más".
- Token en `localStorage` (expuesto a XSS).
- TS strict activado, sin lint configurado ni tests (Angular 21 no define architect `test`).

---

## 7. App Móvil (Flutter)

### Stack

- Flutter (SDK >=3.4), `Material 3` con 4 temas configurables (heritage, ocean, sunset, forest).
- Dependencias: `http`, `sqflite`, `shared_preferences`, `connectivity_plus`, `path_provider`, `file_picker`, `share_plus`, `speech_to_text`, `cupertino_icons`.
- **No scaffolded**: falta `android/`, `ios/`, `web/` y `test/`; hay que ejecutar `flutter create .` para compilar (`build-mobile-apk.ps1` automatiza la compilación APK).

### Estructura `lib/`

- `core/config`: `api_config.dart` (URL base persistida; default `http://10.0.2.2:5000/api`).
- `core/network`: `api_client.dart` (GET/POST/PUT/DELETE/multipart, header Bearer).
- `core/offline`: el corazón de la sincronización.
- `core/storage`, `core/theme`, `core/widgets`.
- `features/`: 13 features con carpetas `presentation/`, `data/`, `domain/`.

### Sincronización offline-first

**Mecanismo**: SQLite (`LocalDatabase`) con 3 tablas locales:

| Tabla | Uso |
|---|---|
| `app_cache` | Cache JSON por clave (colecciones por feature) |
| `offline_queue` | Cola de operaciones pendientes (id, módulo, método, path, payload, estado) |
| `local_users` | Usuarios locales para login offline |

**Flujo**:
1. Toda escritura actualiza primero el cache local (IDs negativos temporales) y encola una `OfflineOperation`.
2. `SyncService` intenta sincronizar de inmediato si el backend es alcanzable (`connectivity_plus` + health-check `GET /health` con timeout 3 s).
3. Reintenta ante cambios de conectividad, cada **30 s** en segundo plano (timer en `HomeShell`) y al volver la app (`resumed`).
4. Las operaciones exitosas se eliminan de la cola; las fallidas quedan marcadas.
5. Registro especial: `/auth/register` con "user already exists" marca el usuario como sincronizado y descarta la operación.

**Cobertura offline**: bancos, cuentas, tarjetas, préstamos, gastos, activos, ingresos, deudores, deudas pequeñas, miembros, planning y categorías. **Inversiones no encola** (escrituras solo online); el dashboard es de solo lectura (merge backend + cache).

**Efectos locales**: gastos ajustan saldo/deuda localmente (`_applyLocalPaymentEffect`), ingresos suman a la cuenta (`_applyLocalIncomeEffect`).

### Pantallas (13)

| Pantalla | Estado |
|---|---|
| Login, Registro | Implementadas (offline-first) |
| HomeShell | Implementada: drawer, NavigationBar, indicador ON/OFF, sync manual y automático |
| Dashboard | Implementada (KPIs, swap de datos) |
| Gastos | Implementada (voz `speech_to_text`, recibos, filtros, FABs) |
| Bancos/Cuentas, Tarjetas/Préstamos, Activos/Ingresos, Deudores/Deudas, Familia, Planificación | Implementadas (CRUD offline-first) |
| Inversiones | Implementada (sin offline en escrituras) |
| Ajustes | Implementada (URL backend, temas, backup import/export, upload/download) |
| **Admin Usuarios** | **Esqueleto** (`ModulePlaceholder`): pendiente migrar CRUD desde web |

### Backup local

`backup_service.dart` exporta/importa JSON de todas las tablas locales (valida `app_id`, `format_version` y tablas requeridas), usando `share_plus` y `file_picker`.

---

## 8. Despliegue

### Opción 1 — Docker Compose completo

`docker-compose.yml`: backend (Flask/Uvicorn en `python:3.12-slim`, puerto 5000, volumen `backend_uploads`). El `DEPLOYMENT.md` describe también servicios `db` y `frontend` (Angular + Nginx). Variables: `DATABASE_URL`, `SECRET_KEY`, `JWT_SECRET_KEY`, `DEFAULT_ADMIN_*`, `BACKEND_PORT`.

- `docker compose up --build -d`
- Frontend en `:8080`, backend health en `:5000/health`.

### Opción 2 — Híbrido (Nginx del servidor + Docker backend)

`deploy-server.sh` automatiza:
1. Compilar Angular (`npm ci && npm run build`).
2. Publicar en `/var/www/family-finance` (rsync o copia).
3. Instalar y recargar config de Nginx desde `deploy/nginx.family-finance.conf.template`.
4. Detener el contenedor `frontend` si existe.
5. Levantar solo el servicio `backend` con Docker.

Variables configurables: `APP_NAME`, `APP_DOMAIN`, `FRONTEND_TARGET_DIR`, `BACKEND_HOST/PORT`, flags `DEPLOY_*`.

### Frontend en contenedor

- `frontend/Dockerfile`: multi-stage `node:22-alpine` build → `nginx:1.27-alpine`.
- `nginx.conf` del contenedor proxy `/api/` y `/health` al servicio `backend:5000`, con fallback SPA `index.html`.

### Móvil

- `build-mobile-apk.ps1`: limpia cache/deps (con reintentos), `flutter clean && flutter pub get` y `flutter build apk --release|--debug`.

---

## 9. Lógica de Negocio Clave

### Efecto de los métodos de pago (gasto)

| Método | Efecto automático |
|---|---|
| Tarjeta Crédito | `card.current_debt += monto`; disponible = límite − deuda |
| Tarjeta Débito | resta a la cuenta vinculada (`bank_account_id`) o al saldo disponible de la tarjeta |
| Banca Móvil | resta a `bank_account.current_balance` |
| Efectivo / Fiado (Fiado sin efecto documentado en backend para tarjetas) | sin efecto en cuentas |

Al editar/borrar se revierte primero (`sign=-1`) y se reaplica.

### Ingresos

- `destination_type = 'cash'` (sin efecto) o `'bank_account'` (suma a `current_balance`).

### Planificación mensual

- POST es "upsert": si existe plan para `(categoría, mes, año)`, actualiza en lugar de duplicar.
- El cálculo "real" agrega gastos del mes por categoría; `remaining = planned − actual`.

### Relaciones familiares

- Al crear/editar un miembro con parentesco, se crea también la relación **inversa** automáticamente (esposa ↔ esposo, padre ↔ hijo/a, etc.).

### Análisis de comprobantes

- PDF vía `pypdf`; imagen vía Tesseract (requiere `TESSERACT_CMD`/binario; sino, avisa que solo PDF).
- Regex para detectar fecha y total; merchant = primera línea relevante; sugiere categorías con keyword map.

### Reportes (5 tipos × 2 formatos)

- `summary`, `movements`, `accounts`, `expenses`, `planning` → **PDF** (generador propio apenas, texto plano paginado) o **XML** (`ElementTree`).

---

## 10. Roles y Permisos

| Recurso | Admin | Member |
|---|---|---|
| Usuarios / admin users | Ve y crea | — (protegido por backend 403 y oculto en UI) |
| Gastos, ingresos, tarjetas, préstamos, deudores, inversiones | Ve todos | Solo los propios (`user_id`) |
| Cuentas bancarias, activos, bancos | Globales | Globales (no filtrate por usuario) |
| Planificación | Comparte planes | Comparte planes (misma query) |
| Dashboard | Sumas globales | Filtra deuda/préstamos/inversiones/gastos propios; **saldo y activos globales** |

Guard frontal: `authGuard` no distingue rol (protección del menú admin solo por UI).

---

## 11. Fortalezas

- **Monolito pragmático**: un backend sirve web y móvil con el mismo contrato API.
- **Offline-first bien resuelto** en móvil (cola transaccional, cache local, re-sync con backoff de 30 s).
- **Lógica financiera automática**: el efecto de pagos en saldos/deudas se mantiene consistente con edición/borrado.
- **Comprobantes**: análisis automático de recibos + almacenamiento seguro por UUID + manifest por gasto.
- **Reportes sin dependencias externas**: PDF generado a mano, portable.
- **Roles y saneamiento de logs** (no se registran tokens/passwords en claro).
- **Migraciones self-healing** al arranque para tablas/columnas nuevas.
- **PWA + instalable** y app móvil con UI pulida (Material 3, 4 temas, backup/restore, entrada por voz).

---

## 12. Deuda Técnica y Riesgos

**Seguridad**
- Token JWT en `localStorage` (XSS) sin refresh ni gestión de expiración en cliente.
- `role` dado por cliente en registro (`POST /auth/register` acepta `role`) — cualquier registro podría pedir `admin`. El rol real admin se crea solo por `DEFAULT_ADMIN`, pero la API no fuerza `member` en registro abierto.
- CORS abierto a `*` (aunque con proxy local y en producción Nginx lo reduce).
- No hay rate-limiting en login (fuerza bruta).
- `SECRET_KEY`/`JWT_SECRET_KEY` con valores por defecto en `config.py` si no se definen.
- Llaves y contraseñas por defecto documentadas (admin/admin) — recomendar cambio en producción.

**Consistencia de datos**
- Divergencia `models.py` vs `database.sql` (`user_id` en `bank_accounts` y `assets`).
- Serialización de fechas inconsistentes (objetos `datetime` sin ISO en algunos GETs).
- Reportes con agregaciones globales para miembros (cuentas, activos, planes, bancos).
- Sin transacciones atómicas entre gasto + efecto de pago (varias escrituras en un commit; posible parcialidad en error).
- `assets` y `income` no respetan `user_id` correctamente en el ORM (assets sin `user_id`, ingreso sí).

**Frontend**
- Sin tests ni lint configurados; código CRUD muy repetitivo (candidato a componentes genéricos).
- Elementos decorativos (buscador, "Cargar más") sin implementar.
- `admin/users` sin `roleGuard`; protección solo por UI + backend.
- No hay refresh token; el 401 fuerza logout.

**Móvil**
- Inversiones sin escritura offline.
- Admin users es esqueleto.
- No scaffolded (`flutter create .` pendiente) — no compila hasta entonces.
- Sin tests.

**Despliegue**
- `docker-compose.yml` actual solo define `backend` (falta `db` y `frontend` que cita `DEPLOYMENT.md`).
- Config por defecto del backend pensada para `FFM_DB` local deprecated vs `family_finance` del README.

---

## 13. Recomendaciones y Próximos Pasos

1. **Forzar rol `member` en registro abierto** en `auth.py` (ignorar `role` del payload o validarlo).
2. **Alinear `models.py` con `database.sql`** (añadir `user_id` a `BankAccount` y `Asset` y filtrar en consultas).
3. **JWT**: añadir refresh token con rotación y expiración manejada en frontend/móvil.
4. **Migraciones**: abandonar ALTERs ad-hoc y usar `flask db migrate`/Alembic con versiones.
5. **Paginación** en listados (gastos, reportes) y filtros reales.
6. **Tests**: añadir lint (`eslint`/`ng lint`) y tests unitarios e2e al menos para la API (pytest) y gastos.
7. **Móvil**: `flutter create .` para habilitar compilación; terminar admin users; implementar offline en inversiones.
8. **Reportes**: reemplazar el generador PDF manual por `reportlab`/`weasyprint` para mejor formato y caracteres latin-1.
9. **Completar `docker-compose.yml`** con servicios `db` y `frontend` para el flujo "todo en Docker".
10. **Seguridad producción**: rotar secretos, HTTPS (Nginx/PM/Traefik), rate-limit login, y eliminar el admin por defecto si no se usa.

---

*Fin del análisis. Este documento debe revisarse cuando cambien `models.py`, `database.sql` o se modifique la arquitectura de despliegue.*