# MiraLlantas — App móvil del cliente (Flutter)

App de un solo rol (cliente). **Cartera es el único módulo con
funcionalidad**: registrar un abono baja el saldo pendiente y eso se
refleja al instante en el historial, en el detalle y en el resumen de
Inicio. Cotizaciones, Entregas y Perfil son visualización con datos de
ejemplo; el perfil se puede editar, pero solo en memoria.

## Cómo ejecutarlo

Verificado con Flutter 3.47.2 (Dart 3.13.2): `flutter analyze` sin
incidencias, 6 pruebas de widget en verde y `flutter build apk --release`
compilando.

```bash
flutter pub get
flutter run
```

Para revisarla en el navegador:

```bash
flutter run -d chrome
```

## Android

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Ojo: la
plantilla de Flutter lo firma con la **clave de debug** (ver el `TODO` en
`android/app/build.gradle.kts`); antes de publicarlo en Play hace falta un
keystore propio.

## Estructura

Todo el código de la app vive en un solo archivo.

```
lib/main.dart                 # app completa: estado de Cartera, tema,
                              # widgets, datos mock y las 14 pantallas
assets/images/                # logo del splash y fotos del carrusel
test/widget_test.dart         # 6 pruebas (navegación + abono real)
mirallantas-prototipo.html    # mockup previo en un solo archivo (*)
android/  web/                # plataformas generadas por flutter create
```

(*) El prototipo HTML corresponde al diseño anterior y **no** refleja
este rediseño; se conserva solo como referencia.

## Pantallas

`Splash` (logo sobre amarillo) → `Login` (sin selector de rol, con
píldora Claro/Oscuro) → `Inicio`. Desde el login se llega a `Recuperar
contraseña`, que son tres pasos: correo, código de 6 dígitos y nueva
contraseña.

La barra inferior tiene cinco pestañas —Inicio, Cotizaciones, Cartera,
Entregas y Perfil— y cada una mantiene su propia pila de navegación, así
que la barra sigue visible dentro de los detalles. El círculo amarillo se
desliza hasta la pestaña elegida y sobresale de la barra, con el icono
saltando dentro.

- **Inicio**: saldo de cartera con barra de cupo, contadores de
  cotizaciones y entregas, próximo pago y carrusel de fotos.
- **Cotizaciones**: listado, detalle con ítems y formulario de nueva
  cotización (campos distintos para llanta nueva y para reencauche).
- **Cartera**: listado, detalle, registrar abono, confirmación e
  historial de abonos.
- **Entregas**: listado y detalle, con evidencia fotográfica o motivo de
  cancelación.
- **Perfil**: datos del cliente, edición en la misma pantalla y cerrar
  sesión.

## Tema

`ThemeController.instance` alterna claro y oscuro; el botón vive en la
cabecera de cada pantalla y en la píldora del login. Ningún widget
declara colores literales: todos leen `Theme.of(context)` o el atajo
`context.palette`.
