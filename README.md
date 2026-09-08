# MiraLlantas — Frontend móvil (Flutter)

Solo UI: no hay autenticación real, llamadas a API ni persistencia.
Todos los datos (nombre, saldo, créditos, módulos) son mock.

## Cómo ejecutarlo

Verificado con Flutter 3.47.2 (Dart 3.13.2): `flutter analyze` sin
incidencias, 7 pruebas de widget en verde y `flutter build web --release`
compilando correctamente.

```bash
flutter pub get
flutter run
```

Para revisarla en el navegador:

```bash
flutter run -d chrome
```

Las rutas admiten deep link con hash: `#/login`, `#/dashboard/usuario`,
`#/dashboard/administrador`, `#/perfil`, `#/cotizaciones`,
`#/cotizaciones/nueva`, `#/creditos`, `#/creditos/detalle`, `#/abonos`,
`#/abonos/nuevo` y `#/entregas`.

## Prototipo en un solo archivo

`mirallantas-prototipo.html` es el mockup completo (React por CDN, sin
build ni dependencias): se abre con doble clic en el navegador y trae las
mismas pantallas que la app, la barra inferior fija, el catálogo de
productos con buscador y el formulario unificado de llanta nueva /
reencauche. Es independiente del código Flutter: los cambios en uno no se
reflejan en el otro.

## Android

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk` (~46 MB,
incluye todas las ABI; con `--split-per-abi` bajan a ~16 MB cada uno).

Ojo: la plantilla de Flutter firma el release con la **clave de debug**
(ver el `TODO` en `android/app/build.gradle.kts`). Antes de publicarlo en
Play hay que crear un keystore propio y su `signingConfig`.

## Estructura

El proyecto está reducido al mínimo: todo el código de la app vive en un
solo archivo.

```
lib/main.dart                 # app completa: tema, rutas, widgets,
                              # datos mock y las 15 pantallas
test/widget_test.dart         # 7 pruebas de widget (flujo completo)
mirallantas-prototipo.html    # mockup independiente en un solo archivo
android/  web/                # plataformas generadas por flutter create
```

Para volver a generar iOS o escritorio: `flutter create . --platforms=ios`.

## Flujo

`Splash` (2,2 s) → `Login`. En el login se elige el rol con el selector
"Acceder como": *Usuario* lleva a `/dashboard/usuario` y *Administrador*
a `/dashboard/administrador`. Desde ambos dashboards se llega a
`Mi Perfil` y a `Cerrar sesión` (vuelve al login limpiando el stack).

## Tema

`ThemeController.instance.toggle()` alterna `ThemeMode.dark` /
`ThemeMode.light`. El botón de sol/luna vive en las cabeceras (dashboards
y perfil) y también en la esquina del login. Los widgets no declaran
colores literales: leen `Theme.of(context)` o `context.palette`.
