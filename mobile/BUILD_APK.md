# Generar APK de Mobile

## APK rápido

Desde la raíz del proyecto:

```powershell
.\build-mobile-apk.ps1
```

Eso genera:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

## Comandos manuales

```powershell
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

## APK debug

```powershell
.\build-mobile-apk.ps1 -Release:$false
```

## Archivo recomendado para Play Store

Si luego quieres subir la app a Play Store, usa mejor:

```powershell
cd mobile
flutter build appbundle --release
```

Eso genera:

```text
mobile\build\app\outputs\bundle\release\app-release.aab
```

## Instalar el APK en el teléfono

Puedes copiar el archivo `app-release.apk` al teléfono y abrirlo, o usar ADB:

```powershell
adb install -r mobile\build\app\outputs\flutter-apk\app-release.apk
```

## Importante para release real

Para una versión final firmada para distribución, más adelante conviene configurar:

- keystore de Android
- `key.properties`
- firma release en `android/app/build.gradle.kts`

Si quieres, puedo dejarte también esa configuración de firma para generar un APK release listo para distribuir.
