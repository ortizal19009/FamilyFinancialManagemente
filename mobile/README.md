# Mobile Flutter

Base Flutter para consumir el mismo backend de la version web.

## Modulos previstos

- Login y registro
- Dashboard
- Gastos
- Bancos y cuentas
- Tarjetas y prestamos
- Planificacion
- Activos e ingresos
- Deudores
- Miembros de familia
- Usuarios admin

## Primer arranque

Cuando tengas Flutter instalado:

```bash
cd mobile
flutter create .
flutter pub get
flutter run
```

## Conexion al backend

La URL base se configura en:

- `lib/core/config/api_config.dart`

Para Android emulator normalmente usaras:

- `http://10.0.2.2:5000/api`

Para dispositivo fisico:

- reemplaza por la IP local de tu maquina, por ejemplo `http://192.168.1.10:5000/api`

## Estado actual

Esta carpeta deja lista la arquitectura y las pantallas base. Los CRUD especificos se pueden ir migrando modulo por modulo desde la app web.

## Modo offline y sincronizacion

La base movil ya contempla un enfoque `offline-first`:

- las operaciones se guardan en el celular cuando no hay acceso al backend
- existe una cola local de sincronizacion
- al volver a tener acceso a la red o al backend, se puede sincronizar manual o automaticamente

El primer modulo aterrizado con esta idea es:

- `Gastos`

Desde ahi ya puedes:

- guardar gastos localmente
- verlos como pendientes
- sincronizarlos luego con el backend
