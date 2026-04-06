# Planificación del Sistema de Gestión Financiera Familiar

Este documento detalla los módulos y pasos necesarios para construir el sistema de control de finanzas.

## Arquitectura del Sistema
- **Backend:** Python Flask (API RESTful) con SQLAlchemy (ORM).
- **Frontend:** Angular con configuración PWA (Progressive Web App).
- **Base de Datos:** PostgreSQL.
- **Autenticación:** JSON Web Tokens (JWT).

---

## 1. Módulo de Autenticación y Usuarios
- Registro de integrantes de la familia.
- Login con roles (Administrador y Miembro).
- Gestión de perfiles.

## 2. Módulo de Entidades Financieras (Bancos y Cooperativas)
- CRUD de bancos y cooperativas afiliados.
- Gestión de cuentas bancarias (Ahorros/Corriente).
- Visualización de saldos en tiempo real (actualizados por transacciones).

## 3. Módulo de Tarjetas y Préstamos
- **Tarjetas:** Gestión de tarjetas de crédito y débito. Control de cupos, saldos a favor y deudas actuales.
- **Préstamos:** Registro de préstamos bancarios. Seguimiento de monto inicial, número de cuotas, cuotas pendientes y pagos realizados.

## 4. Módulo de Inventario de Bienes
- Registro de activos (vehículos, propiedades, electrodomésticos, etc.).
- Valoración actual para el cálculo del patrimonio familiar total.

## 5. Módulo de Gestión de Ingresos y Deudores
- Registro de sueldos y otros ingresos mensuales.
- Gestión de "Cuentas por Cobrar" (personas que deben dinero a la familia).

## 6. Módulo de Gastos y Planificación
- **Gastos Diarios:** Registro rápido de gastos por integrante. Opciones de pago: Efectivo, Tarjeta (Crédito/Débito), Banca Móvil, Fiado.
- **Planificación Mensual:** Presupuesto por categorías (Alimentos, Medicina, Vivienda, Transporte, etc.). Comparativa entre lo planeado y lo gastado.

## 7. Panel de Control (Admin Dashboard)
- Gráficos estadísticos de ingresos vs gastos.
- Resumen de patrimonio total (Activos - Deudas).
- Monitoreo de actividad de todos los integrantes.

---

## Próximos Pasos (Hoja de Ruta)
1.  **Semana 1:** Configuración de base de datos y desarrollo de API de autenticación y bancos.
2.  **Semana 2:** Módulos de tarjetas, préstamos y activos.
3.  **Semana 3:** Registro de gastos, ingresos y planificación mensual.
4.  **Semana 4:** Desarrollo del Frontend en Angular, integración de PWA y despliegue inicial.
