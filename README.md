# MiraLlantas — App móvil del cliente (Flutter)

App del portal del cliente con las secciones propias de la móvil —Inicio,
Cotizaciones, Cartera y Perfil— y el estilo, los estados y las
reglas del portal web de MiraLlantas (colores de marca, pastillas de
estado, etapas de la cotización, crédito y abonos).

Los datos son de ejemplo y viven en memoria: aceptar o cancelar una
cotización y registrar un abono actualizan todas las pantallas, pero
todavía no se envía nada al servidor.

## Cómo ejecutarlo

Verificado con Flutter 3.47.9 (Dart 3.13.7): `flutter analyze` sin
incidencias y 16 pruebas de widget en verde.

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
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/simbolos
```

Genera un APK liviano por tipo de procesador en
`build/app/outputs/flutter-apk/`: `app-arm64-v8a-release.apk` (la mayoría
de teléfonos, ~17 MB) y `app-armeabi-v7a-release.apk` (teléfonos viejos de
32 bits). El APK universal pesaba ~48 MB. Ojo: la
plantilla de Flutter lo firma con la **clave de debug** (ver el `TODO` en
`android/app/build.gradle.kts`); antes de publicarlo en Play hace falta un
keystore propio.

## Estructura

Todo el código de la app vive en un solo archivo.

```
lib/main.dart                 # app completa: estado de cartera y
                              # cotizaciones, tema, widgets, datos de
                              # ejemplo y las pantallas
assets/images/                # logo del splash y fotos del carrusel
test/widget_test.dart         # 16 pruebas (acceso, navegación, abonos
                              # y cotizaciones)
mirallantas-prototipo.html    # mockup previo en un solo archivo (*)
android/  web/                # plataformas generadas por flutter create
```

(*) El prototipo HTML corresponde al diseño anterior y **no** refleja
este rediseño; se conserva solo como referencia.

## Pantallas

`Splash` (fondo azul medianoche, logo y barra amarilla que se llena, como
en la web) → `Login` → pantalla de carga "Preparando tu panel…" →
`Inicio`. El login tiene:

- correo y contraseña con validación;
- **Recordarme**: guarda en el teléfono solo el correo (nunca la
  contraseña) y lo deja escrito la próxima vez;
- **Google**: por ahora es de demostración y entra con la cuenta del
  perfil. Para el inicio real hacen falta el ID de cliente OAuth de Google
  y que el backend verifique la cuenta;
- **Huella o rostro**: usa el desbloqueo biométrico de Android (huella o
  reconocimiento facial, el que esté configurado) y entra con la cuenta
  recordada (hay que haber entrado una vez con "Recordarme"). Solo aparece
  si el teléfono tiene biometría configurada. La app es solo para Android.

Desde el login se llega a `Recuperar contraseña`: correo, código de 6
dígitos, contraseña nueva (mínimo 10 caracteres, con letras y números) y
confirmación.

La barra inferior tiene cuatro pestañas —Inicio, Cotizaciones, Cartera y
Perfil— y cada una mantiene su propia pila de navegación, así que la barra
sigue visible dentro de los detalles.

- **Inicio**: los indicadores del portal (pedidos-cotización, próxima
  entrega, mi crédito, total comprado y estado del crédito), las
  cotizaciones recientes y el carrusel de fotos.
- **Cotizaciones**: buscador, filtros por etapa y por **estado de
  entrega** (así se siguen las entregas, que ya no tienen pestaña propia;
  "Próxima entrega" de Inicio abre este filtro) y una tarjeta por
  cotización con sus cinco estados (etapa, crédito, pago, cotización y
  entrega). Una cotización formal se puede aceptar (contado o crédito) y,
  mientras no se acepte, cancelar con un motivo. El detalle muestra
  fechas, productos y servicios, pago, seguimiento de la entrega y el
  crédito.
- **Cartera**: estado del crédito, créditos con sus abonos y solicitudes
  de crédito. El abono sigue las reglas de la web: mínimo de $ 20.000 (o
  el saldo exacto), efectivo o transferencia, y pantallazo obligatorio en
  transferencia. Queda **pendiente** hasta que un asesor lo valide; un
  abono rechazado se puede volver a subir.
- **Perfil**: tipo y número de documento, nombre, dirección, correo y
  teléfono; el cambio de contraseña o de correo pide la contraseña actual.

## Tema

Los colores son los de la web (`frontend/tailwind.config.js`): amarillo de
marca `#F4C400`, azul industrial `#17375E`, carbón `#24282D` y azul
medianoche `#081426` para el modo oscuro. `ThemeController.instance`
alterna claro y oscuro; el botón vive en la cabecera de cada pantalla. Los widgets leen los colores de `Theme.of(context)`
o del atajo `context.palette`.

Las fuentes de la web (Plus Jakarta Sans y Archivo) todavía no están en
la app: usa la fuente del sistema.
