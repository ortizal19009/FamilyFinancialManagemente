# Sistema de Control de Finanzas Familiar

Este sistema integral permite monitorear y gestionar todas las finanzas de la familia, incluyendo bancos, cuentas, tarjetas, préstamos, gastos diarios, ingresos, planificación mensual y activos.

---

## 🚀 Guía de Ejecución

### 1. Requisitos Previos
- **Python 3.10+**
- **Node.js 18+** y **Angular CLI**
- **PostgreSQL** (Servidor corriendo)

---

### 2. Configuración de la Base de Datos
1. Crea una base de datos en PostgreSQL llamada `family_finance`.
2. Ejecuta el script SQL proporcionado para crear las tablas:
   ```bash
   psql -U tu_usuario -d family_finance -f database.sql
   ```

---

### 3. Ejecutar el Backend (Python Flask con Uvicorn)
1. Desde la raíz del proyecto, usa el script recomendado:
   ```powershell
   .\start-backend.ps1
   ```
2. Configura las credenciales de la base de datos:
   - Abre el archivo `.env` en la carpeta `backend/`.
   - Asegúrate de que `DATABASE_URL` tenga el usuario, contraseña y nombre de base de datos correctos.
   - Ejemplo: `DATABASE_URL=postgresql+psycopg://usuario:contraseña@localhost/nombre_bd`
3. Instala las dependencias (Compatible con Python 3.14+):
   ```powershell
   .\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
   ```
4. Si prefieres iniciarlo manualmente desde la raíz:
   ```powershell
   .\.venv\Scripts\python.exe -m uvicorn backend.app:asgi_app --host 127.0.0.1 --port 5000 --reload
   ```
   *Si lo ejecutas dentro de `backend/`, usa `..\.venv\Scripts\python.exe -m uvicorn app:asgi_app --host 127.0.0.1 --port 5000 --reload`.*
   *Alternativamente, puedes usar `py backend\app.py` para el modo de desarrollo estándar.*
   *El backend correrá en `http://localhost:5000`*

---

### 4. Ejecutar el Frontend (Angular PWA)
1. Entra a la carpeta del frontend:
   ```bash
   cd frontend
   ```
2. Instala las dependencias de Node:
   ```bash
   npm install
   ```
3. Inicia el servidor de desarrollo:
   ```bash
   npm start
   ```
   *En desarrollo, Angular usa un proxy local para redirigir `/api` al backend en `http://127.0.0.1:5000`, evitando el costo extra de CORS/preflight entre puertos.*
   *El frontend correrá en `http://localhost:4200`*

---

### 5. Base Mobile (Flutter)
Existe una base inicial en la carpeta `mobile/` para llevar las mismas opciones de la version web a una app movil.

Cuando tengas Flutter instalado:

```bash
cd mobile
flutter create .
flutter pub get
flutter run
```

La URL del backend para la app movil se configura en:

```text
mobile/lib/core/config/api_config.dart
```

La base movil tambien ya contempla sincronizacion offline-first:

- el celular puede guardar operaciones locales cuando no hay acceso al backend
- luego puede sincronizarlas cuando vuelva a estar en la red correcta o tenga acceso al servidor
- el primer flujo implementado bajo este enfoque es el de `Gastos`

---

## 📖 Manual de Usuario

### 🔐 Autenticación
- **Registro**: Cada integrante de la familia debe crear una cuenta.
- **Login**: Acceso seguro con JWT. La pantalla cuenta con un carrusel de fotos familiares inspiradoras.

### 📊 Dashboard (Panel General)
- Visualiza de un vistazo tu **Saldo Disponible**, **Deuda Total**, **Gastos del Mes** y **Patrimonio Total**.
- Revisa los últimos 5 gastos registrados recientemente.

### 🏦 Bancos y Cuentas
- **Bancos**: Registra las entidades financieras (Bancos o Cooperativas).
- **Cuentas**: Crea cuentas de ahorros o corriente vinculadas a un banco con su saldo inicial.

### 💸 Gastos Diarios
- Registra lo que compras cada día.
- **Métodos de Pago**: Elige entre Efectivo, Tarjeta (Crédito/Débito), Banca Móvil o Fiado.
- **Impacto Automático**: Si pagas con débito, se resta de tu cuenta bancaria. Si usas crédito, aumenta tu deuda en la tarjeta.

### 💳 Tarjetas y Préstamos
- **Tarjetas**: Monitorea el cupo disponible y la deuda actual de tus tarjetas de crédito.
- **Préstamos**: Registra créditos bancarios, indicando monto inicial, cuotas totales y pendientes. El sistema muestra una barra de progreso de pago.

### 📅 Planificación Mensual
- Define presupuestos por categoría (Alimentos, Medicina, Transporte, etc.).
- Compara en tiempo real lo que **planeaste gastar** contra lo que **realmente has gastado**.
- Las barras de progreso cambian a rojo si te excedes del presupuesto.

### 🏠 Patrimonio (Bienes e Ingresos)
- **Inventario**: Registra tus activos (casa, vehículos, etc.) para calcular tu progreso financiero real.
- **Ingresos**: Registra sueldos, bonos o ventas para llevar el control de entradas.

### 👥 Deudores
- Anota a las personas que le deben dinero a la familia.
- Marca como "Pagado" cuando recibas el dinero para actualizar el balance.

---

## 📱 Instalación como PWA
Al abrir la aplicación en tu celular (usando el navegador Chrome o Safari), verás una opción para **"Añadir a la pantalla de inicio"**. Esto instalará el sistema como una aplicación móvil nativa.
