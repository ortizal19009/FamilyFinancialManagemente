# Plan de Correcciones, Mejoras y Evolución

**Sistema:** Family Financial Management
**Fecha:** septiembre de 2026

**Objetivo:** definir una hoja de ruta técnica para corregir riesgos actuales, fortalecer la seguridad y consistencia financiera, completar funcionalidades pendientes y preparar la aplicación para crecimiento futuro.

---

## 1. Objetivos de la mejora

La evolución del sistema se plantea con los siguientes objetivos:

- Corregir inconsistencias entre base de datos, ORM, backend, frontend y aplicación móvil.
- Fortalecer autenticación, autorización y seguridad de producción.
- Garantizar que cada usuario visualice y modifique únicamente la información que le corresponde.
- Mejorar la integridad de movimientos financieros y evitar saldos parciales o inconsistentes.
- Completar la estrategia offline-first de la aplicación móvil.
- Profesionalizar reportes, auditoría, despliegues y migraciones.
- Preparar la arquitectura para incorporar nuevos módulos sin romper el flujo actual.
- Mantener compatibilidad con los datos existentes mediante migraciones controladas.

---

## 2. Prioridad 0 — Respaldo y estabilización antes de modificar

Antes de aplicar cambios estructurales:

- Generar backup completo de PostgreSQL.
- Respaldar archivos/comprobantes almacenados.
- Crear una rama de trabajo, por ejemplo: `feature/ffm-v2-hardening`.
- Levantar un ambiente de pruebas separado de producción.
- Documentar variables de entorno actuales.
- Obtener una copia del esquema real de producción.
- Comparar:
  - `database.sql`
  - `backend/models.py`
  - esquema PostgreSQL real.
- Crear pruebas mínimas de regresión sobre:
  - login;
  - usuarios;
  - cuentas;
  - tarjetas;
  - préstamos;
  - ingresos;
  - gastos;
  - planificación;
  - dashboard;
  - reportes.
- No ejecutar modificaciones destructivas automáticas al iniciar el backend.

---

## 3. Seguridad — Prioridad crítica

### 3.1 Registro público

**Problema:** el endpoint de registro no debe confiar en un campo `role` enviado por el cliente.

**Corrección:** en registro público:

- ignorar cualquier `role` recibido;
- asignar obligatoriamente `member`;
- reservar la creación/asignación de administradores para endpoints protegidos.

**Criterio de aceptación:** un usuario no autenticado nunca podrá convertirse en admin manipulando el JSON de registro.

### 3.2 JWT y sesiones

Implementar:

- access token de corta duración;
- refresh token;
- rotación/revocación de refresh tokens;
- cierre de sesión real;
- manejo centralizado de expiración;
- invalidación de sesiones cuando corresponda.

**Frontend:** evitar depender únicamente de `localStorage` para credenciales de larga duración. Evaluar una estrategia con cookies `HttpOnly`, `Secure` y `SameSite` cuando la arquitectura de despliegue lo permita.

### 3.3 Control de acceso por rol

Crear autorización explícita para rutas administrativas. Ejemplo conceptual:

- `authGuard`: usuario autenticado.
- `adminGuard`: usuario autenticado + rol administrador.

Backend: autorización obligatoria independientemente del frontend. La seguridad nunca debe depender únicamente de ocultar opciones del menú.

### 3.4 Rate limiting

Aplicar límites especialmente en:

- `/api/auth/login`
- `/api/auth/register`
- recuperación de credenciales futura;
- análisis/subida de comprobantes.

Registrar intentos fallidos sin almacenar contraseñas.

### 3.5 Secretos

Eliminar valores inseguros por defecto para:

- `SECRET_KEY`
- `JWT_SECRET_KEY`
- usuario administrador;
- contraseña administrativa.

En producción, el backend debe fallar al iniciar si faltan secretos obligatorios.

### 3.6 CORS y HTTPS

- Restringir CORS a los dominios autorizados.
- Forzar HTTPS.
- Configurar cabeceras de seguridad.
- Definir límites de tamaño para archivos.
- Validar MIME, extensión y contenido permitido de comprobantes.

---

## 4. Base de datos y modelo de datos

### 4.1 Eliminar divergencias ORM/SQL

Corregir la inconsistencia detectada en:

- `bank_accounts.user_id`
- `assets.user_id`

Definir una única fuente de verdad mediante migraciones versionadas.

### 4.2 Propiedad de los registros

Cada entidad financiera que deba pertenecer a un usuario debe contar con propietario explícito. Revisar como mínimo:

- cuentas;
- tarjetas;
- préstamos;
- activos;
- inversiones;
- ingresos;
- gastos;
- deudores;
- deudas pequeñas.

**Regla:** un usuario `member`:

- consulta sus registros;
- crea sus registros;
- modifica sus registros;
- elimina sus registros.

Un admin podrá consultar información global únicamente cuando la política funcional lo permita.

### 4.3 Migraciones

Eliminar progresivamente los `ALTER TABLE` automáticos ejecutados durante el arranque. Adoptar Alembic/Flask-Migrate:

```
migrations/
  versions/
    001_initial_schema.py
    002_add_account_owner.py
    003_add_asset_owner.py
    004_audit_tables.py
```

Toda actualización deberá tener:

- `upgrade`;
- estrategia de `rollback`;
- respaldo previo;
- validación posterior.

---

## 5. Integridad de movimientos financieros

Este debe ser uno de los cambios principales.

### 5.1 Transacciones atómicas

Operaciones como *crear gasto → afectar tarjeta/cuenta → guardar comprobante* deben ejecutarse como una única unidad lógica. Si una operación falla, se revierte toda la transacción.

Aplicar el mismo criterio a:

- edición de gasto;
- eliminación/anulación;
- ingreso a cuenta;
- pagos de deuda;
- movimientos de tarjetas;
- sincronización móvil.

### 5.2 Evitar eliminación física de movimientos financieros

Para información financiera se recomienda incorporar estados:

- `ACTIVO`
- `ANULADO`
- `REVERSADO`

En lugar de borrar físicamente un movimiento, conservarlo y registrar:

- usuario que realizó la acción;
- fecha/hora;
- motivo;
- valor original;
- estado anterior;
- estado nuevo.

### 5.3 Libro de movimientos

Se recomienda evolucionar hacia una tabla central de movimientos. Ejemplo:

```
financial_movements
- id
- user_id
- movement_type
- source_type
- source_id
- account_id
- card_id
- amount
- direction
- movement_date
- status
- description
- created_at
- created_by
```

Esto permitirá construir saldos, historial y auditoría con mayor confiabilidad.

---

## 6. Auditoría y trazabilidad

Añadir una bitácora de auditoría:

```
audit_log
- id
- user_id
- action
- entity
- entity_id
- old_values
- new_values
- ip_address
- created_at
```

Registrar como mínimo:

- creación;
- edición;
- anulación;
- reversión;
- cambio de rol;
- cambios de configuración;
- importaciones;
- sincronizaciones críticas.

Crear una pantalla administrativa: **Administración → Auditoría**, con filtros por:

- fecha;
- usuario;
- módulo;
- acción;
- registro.

---

## 7. Dashboard

Mejorar el dashboard para que no sea únicamente un resumen estático.

**KPIs propuestos:**

- saldo disponible;
- ingresos del mes;
- gastos del mes;
- ahorro mensual;
- porcentaje de ahorro;
- deuda total;
- patrimonio;
- inversiones;
- cuentas por cobrar;
- deudas por pagar;
- presupuesto utilizado;
- gastos pendientes de sincronización.

**Gráficos:**

- ingresos vs. gastos por mes;
- gastos por categoría;
- evolución del patrimonio;
- evolución de deuda;
- presupuesto vs. ejecución;
- distribución de activos;
- distribución de dinero por institución financiera.

**Selector de rango:**

- mes;
- trimestre;
- semestre;
- año;
- rango personalizado.

---

## 8. Presupuestos y planificación

Evolucionar `monthly_planning` hacia un módulo real de presupuesto.

**Agregar:**

- presupuesto general mensual;
- presupuesto por categoría;
- presupuesto por integrante;
- comparación planificado/ejecutado;
- porcentaje consumido;
- saldo disponible;
- arrastre opcional;
- duplicar planificación del mes anterior.

**Alertas:**

- 75 % utilizado;
- 90 % utilizado;
- 100 % alcanzado;
- presupuesto excedido.

---

## 9. Cuentas y bancos

**Agregar:**

- número de cuenta parcialmente oculto;
- titular;
- tipo;
- moneda;
- saldo inicial;
- saldo actual;
- saldo conciliado;
- estado activa/inactiva;
- fecha de corte o actualización.

**Transferencias:**

Crear operación de transferencia entre cuentas. Debe generar:

- egreso en origen;
- ingreso en destino;
- identificador común de transferencia.

Nunca manejarla como dos operaciones manuales independientes.

---

## 10. Tarjetas de crédito

**Ampliar información:**

- cupo;
- deuda actual;
- cupo disponible;
- fecha de corte;
- fecha máxima de pago;
- pago mínimo;
- pago total;
- tasa;
- estado.

**Módulo de pagos de tarjeta.** Un pago deberá:

- descontar dinero de una cuenta;
- disminuir deuda de tarjeta;
- registrar movimiento;
- conservar trazabilidad.

---

## 11. Préstamos

**Agregar:**

- capital inicial;
- saldo capital;
- tasa;
- plazo;
- cuota;
- fecha de inicio;
- próxima cuota;
- cuotas pagadas;
- cuotas pendientes;
- estado.

**Tabla de amortización.** Generar:

- número de cuota;
- capital;
- interés;
- cuota;
- saldo;
- vencimiento;
- estado.

Permitir registrar pagos y abonos extraordinarios.

---

## 12. Ingresos

Mejorar el módulo para soportar:

- sueldo;
- honorarios;
- ventas;
- intereses;
- dividendos;
- alquileres;
- otros.

**Agregar:**

- ingreso recurrente;
- frecuencia;
- fecha prevista;
- destino;
- comprobante;
- observación.

---

## 13. Gastos

**Mejoras funcionales:**

- búsqueda real;
- paginación;
- filtros;
- comercio/proveedor;
- etiquetas;
- ubicación opcional;
- gasto recurrente;
- notas;
- comprobante;
- estado;
- moneda.

**Filtros:**

- rango de fechas;
- categoría;
- usuario;
- método;
- cuenta;
- tarjeta;
- monto;
- comercio.

Eliminar el botón decorativo "Cargar más" o implementar paginación real.

---

## 14. Comprobantes

Mantener el análisis actual pero mejorar el flujo:

1. subir imagen/PDF;
2. validar archivo;
3. almacenar con UUID;
4. extraer texto;
5. detectar: fecha, establecimiento, subtotal, impuestos, total;
6. sugerir categoría;
7. permitir confirmación manual;
8. asociar al movimiento.

El OCR nunca debe registrar automáticamente un movimiento financiero sin confirmación del usuario.

---

## 15. Deudas y cuentas por cobrar

**Separar conceptualmente:**

- **Cuentas por cobrar** — dinero que terceros deben al usuario.
- **Cuentas por pagar** — dinero que el usuario debe a terceros.

**Añadir:**

- fecha;
- vencimiento;
- monto inicial;
- saldo pendiente;
- abonos;
- persona;
- observación;
- estado.

**Estados:**

- `PENDIENTE`
- `PARCIAL`
- `PAGADO`
- `VENCIDO`
- `ANULADO`

---

## 16. Inversiones

- Completar el módulo móvil offline-first.
- **Agregar:** capital invertido, valor actual, rendimiento monetario, rendimiento porcentual, fecha de inversión, vencimiento, tasa esperada, institución, tipo, estado.
- **Historial opcional:**

```
investment_valuations
- investment_id
- valuation_date
- amount
```

Permitirá graficar evolución.

---

## 17. Familia

Mantener miembros y relaciones, pero separar claramente:

- usuario de acceso;
- integrante familiar;
- propietario financiero.

No todos los integrantes necesitan iniciar sesión.

**Permisos futuros:**

- puede ver información familiar;
- puede registrar gastos;
- puede administrar presupuestos;
- puede consultar patrimonio;
- puede administrar miembros.

---

## 18. Reportes

El generador PDF actual debe evolucionar. Utilizar una solución que soporte:

- encabezado;
- logo;
- tablas;
- totales;
- numeración;
- fechas;
- caracteres UTF-8;
- filtros;
- pie de página.

**Reportes propuestos:**

- resumen financiero;
- ingresos;
- gastos;
- gastos por categoría;
- cuentas;
- tarjetas;
- préstamos;
- amortización;
- inversiones;
- activos;
- deudas;
- presupuesto;
- patrimonio;
- movimientos;
- auditoría.

**Formatos:** PDF, XLSX, CSV, XML cuando sea requerido.

---

## 19. Frontend Angular

**Correcciones:**

- cambiar `<html lang="en">` a `es`;
- personalizar nombre e iconos PWA;
- implementar `adminGuard`;
- reemplazar `window.confirm` por modal consistente;
- crear componentes reutilizables;
- eliminar `any` progresivamente;
- agregar manejo centralizado de errores;
- implementar paginación;
- implementar buscadores reales;
- añadir skeleton/loading uniforme.

**Arquitectura sugerida:**

```
core/
shared/
features/
  dashboard/
  expenses/
  income/
  accounts/
  cards/
  loans/
  planning/
  investments/
  debts/
  family/
  reports/
  admin/
```

---

## 20. Aplicación Flutter

**Prioridad:**

- Ejecutar y versionar correctamente el scaffold Flutter.
- Validar Android.
- Completar Admin Usuarios.
- Completar inversiones offline.
- Añadir resolución de conflictos.
- Mejorar sincronización.
- Añadir pruebas.

---

## 21. Sincronización offline

La cola actual es una fortaleza, pero debe robustecerse.

**Agregar a cada operación:**

- UUID;
- dispositivo;
- fecha local;
- fecha servidor;
- versión;
- número de reintentos;
- último error;
- estado.

**Estados:** `PENDING`, `SYNCING`, `SYNCED`, `FAILED`, `CONFLICT`.

**Idempotencia:** toda operación móvil debe incluir una clave idempotente. El backend no debe duplicar un gasto porque el dispositivo haya reenviado la misma operación.

---

## 22. Resolución de conflictos

Definir comportamiento cuando:

- móvil modifica un registro offline;
- web modifica el mismo registro;
- móvil vuelve a conectarse.

No resolver silenciosamente. Como mínimo almacenar:

- versión local;
- versión servidor;
- fecha;
- usuario;
- dispositivo.

---

## 23. Notificaciones

Añadir un centro de alertas para:

- presupuesto próximo a agotarse;
- tarjeta próxima a fecha de pago;
- préstamo próximo a vencer;
- deuda vencida;
- inversión próxima a vencer;
- sincronización fallida;
- movimientos importantes.

La primera versión puede ser interna; posteriormente se podrá ampliar a push/email.

---

## 24. Configuración del sistema

Crear módulo **Configuración** con secciones:

- perfil;
- familia;
- moneda;
- zona horaria;
- categorías;
- métodos de pago;
- notificaciones;
- seguridad;
- sesiones/dispositivos;
- apariencia;
- backup;
- sincronización.

---

## 25. Multimoneda

Preparar el modelo aunque inicialmente se utilice USD.

- `currency_code`;
- moneda principal familiar;
- moneda por cuenta;
- moneda por movimiento.

No implementar conversiones automáticas hasta definir fuente y política de tipos de cambio.

---

## 26. Backups

Además del backup móvil local:

- backup programado PostgreSQL;
- backup de comprobantes;
- política de retención;
- restauración documentada;
- prueba periódica de restauración.

> Un backup que nunca ha sido restaurado en pruebas no debe considerarse validado.

---

## 27. API

- Versionar progresivamente: `/api/v1/`.
- Estandarizar respuestas:

```json
{
  "success": true,
  "data": {},
  "message": null,
  "errors": []
}
```

- Agregar: paginación, filtros, ordenamiento, validación de payload, códigos HTTP coherentes, identificador de error.
- No devolver excepciones SQL directamente al cliente.

---

## 28. Documentación de API

Incorporar OpenAPI/Swagger con:

- endpoints;
- parámetros;
- esquemas;
- ejemplos;
- respuestas;
- autenticación;
- códigos de error.

Esto será especialmente útil porque Angular y Flutter consumen el mismo backend.

---

## 29. Pruebas

**Backend (pytest):**

- autenticación;
- permisos;
- gastos;
- reversión;
- ingresos;
- cuentas;
- tarjetas;
- préstamos;
- planificación;
- reportes;
- sincronización/idempotencia.

**Casos financieros críticos (obligatorios):**

| Saldo inicial | Operación | Saldo esperado |
|---|---|---|
| 1000 | Gasto: 100 | 900 |
| 1000 | Editar gasto a 150 | 850 |
| 1000 | Anular gasto | 1000 |

Estas pruebas deben ser obligatorias.

---

## 30. Observabilidad

Agregar:

- logs estructurados;
- request ID;
- usuario;
- endpoint;
- duración;
- código HTTP.

**Nunca registrar:** contraseñas, JWT, secretos, documentos completos sensibles.

Health checks diferenciados:

- `/health`
- `/health/database`

---

## 31. Docker y despliegue

- Alinear documentación con implementación real.
- Crear un `docker-compose.yml` completo: `postgres`, `backend`, `frontend`.
- Opcional: `redis` para rate limiting, cache o trabajos futuros.
- Separar `env` por ambiente (development, staging, production).
- Nunca versionar secretos reales.

---

## 32. CI/CD

Agregar pipeline:

1. instalar dependencias;
2. lint;
3. tests backend;
4. tests frontend;
5. build Angular;
6. validar Flutter;
7. construir imágenes;
8. publicar;
9. desplegar únicamente si las validaciones pasan.

---

## 33. Orden de implementación recomendado

**Fase 1 — Correcciones críticas**

- seguridad del registro;
- secretos;
- permisos;
- modelo/SQL;
- ownership;
- transacciones financieras;
- errores backend;
- migraciones.

**Fase 2 — Calidad financiera**

- auditoría;
- anulaciones/reversiones;
- movimientos;
- transferencias;
- pagos de tarjetas;
- préstamos/amortización.

**Fase 3 — UX y reportes**

- dashboard;
- filtros;
- paginación;
- reportes profesionales;
- alertas;
- configuración.

**Fase 4 — Mobile**

- scaffold;
- admin;
- inversiones offline;
- idempotencia;
- conflictos;
- pruebas de sincronización.

**Fase 5 — Infraestructura**

- Docker completo;
- CI/CD;
- backups;
- observabilidad;
- OpenAPI.

---

## 34. Regla principal de migración

Las mejoras deben implementarse sin romper el flujo existente.

Por cada cambio:

1. Crear migración.
2. Mantener compatibilidad temporal.
3. Actualizar backend.
4. Ejecutar pruebas.
5. Actualizar Angular.
6. Actualizar Flutter.
7. Validar datos existentes.
8. Desplegar en pruebas.
9. Respaldar producción.
10. Desplegar.
11. Validar.

> No renombrar/eliminar columnas utilizadas por clientes existentes hasta haber migrado todos los consumidores.

---

## 35. Resultado esperado

Al finalizar esta evolución, Family Financial Management deberá contar con:

- seguridad reforzada;
- datos separados correctamente por propietario;
- operaciones financieras transaccionales;
- trazabilidad completa;
- mejores presupuestos;
- dashboard financiero avanzado;
- administración de cuentas, tarjetas y préstamos más completa;
- reportes profesionales;
- web y móvil consistentes;
- sincronización offline confiable;
- migraciones versionadas;
- backups;
- pruebas automatizadas;
- despliegue reproducible;
- arquitectura preparada para incorporar nuevos módulos.

---

## Pendiente de especificación

El requerimiento recibido indica además que se desea **"añadirle…"**, pero la funcionalidad concreta quedó incompleta en la solicitud. Una vez definida, debe incorporarse a este documento como un módulo/requerimiento adicional, indicando:

- objetivo;
- alcance;
- tablas;
- endpoints;
- pantallas Angular;
- pantallas Flutter;
- permisos;
- reglas de negocio;
- funcionamiento offline;
- reportes;
- auditoría;
- criterios de aceptación.

---

*Documento de hoja de ruta. Complementa el análisis técnico registrado en `ANALISIS.md`.*