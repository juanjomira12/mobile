// Pruebas de humo de la app: acceso, navegación, barra inferior y los dos
// módulos con estado en memoria (Cartera y Cotizaciones).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mirallantas/main.dart';

/// Biometría simulada: el teléfono ofrece [tipos] y la verificación
/// responde [aprueba].
class _BiometriaFalsa extends LocalAuthPlatform {
  _BiometriaFalsa(this.tipos, {this.aprueba = true});

  final List<BiometricType> tipos;
  final bool aprueba;
  int intentos = 0;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => tipos;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    intentos++;
    return aprueba;
  }
}

/// Arranca la app y deja el splash atrás.
Future<void> _abrirLogin(WidgetTester tester) async {
  await tester.pumpWidget(const MiraLlantasApp());
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// En las pruebas la barra inferior se toca por icono. El `.last` evita
/// chocar con los iconos iguales de las tarjetas de Inicio.
Future<void> _irA(WidgetTester tester, IconData icono) async {
  await tester.tap(find.byIcon(icono).last);
  await tester.pumpAndSettle();
}

/// Arranca la app, inicia sesión y espera la pantalla de carga.
Future<void> _entrar(WidgetTester tester) async {
  await _abrirLogin(tester);
  await tester.enterText(find.byType(TextField).at(0), 'carlos@correo.com');
  await tester.enterText(find.byType(TextField).at(1), 'clave12345');
  await tester.tap(find.byKey(const Key('login-entrar')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeController.instance.set(false);
    ShellController.instance.filtroEntrega.value = null;
    // Las pruebas comparten el estado en memoria: se deja como al inicio.
    CarteraStore.instance.reiniciar();
    CotizacionesStore.instance.reiniciar();
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(420, 2200);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('el splash da paso al login', (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MiraLlantas'), findsOneWidget);
    expect(find.text('Cargando...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-entrar')), findsOneWidget);
    expect(find.text('Accede a tu cuenta'), findsOneWidget);
    expect(find.text('Recordarme'), findsOneWidget);
    expect(find.byKey(const Key('login-google')), findsOneWidget);
    // Sin selector de tema ni de rol en el login.
    expect(find.text('Claro'), findsNothing);
    expect(find.text('Administrador'), findsNothing);
    // En las pruebas no hay biometría: el botón de huella no aparece.
    expect(find.byKey(const Key('login-huella')), findsNothing);
  });

  testWidgets('"Recordarme" guarda el correo para la próxima vez',
      (WidgetTester tester) async {
    await _abrirLogin(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Carlos@Correo.com');
    await tester.enterText(find.byType(TextField).at(1), 'clave12345');
    await tester.tap(find.byKey(const Key('login-recordar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(await SesionGuardada.correo(), 'carlos@correo.com');

    // Al volver a abrir la app, el correo ya está escrito.
    await tester.pumpWidget(const SizedBox());
    await _abrirLogin(tester);
    expect(find.text('carlos@correo.com'), findsOneWidget);
  });

  testWidgets('con huella o rostro se entra a la cuenta recordada',
      (WidgetTester tester) async {
    final falsa = _BiometriaFalsa([BiometricType.strong]);
    LocalAuthPlatform.instance = falsa;
    SharedPreferences.setMockInitialValues({
      'recordar_correo': 'carlos@correo.com',
    });

    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('login-huella')));
    await tester.pumpAndSettle();
    expect(falsa.intentos, 1);
    expect(find.text('Hola, Carlos'), findsOneWidget);
  });

  testWidgets('el botón de huella o rostro pide una cuenta recordada',
      (WidgetTester tester) async {
    LocalAuthPlatform.instance = _BiometriaFalsa([BiometricType.weak]);

    await _abrirLogin(tester);
    expect(find.text('Huella o rostro'), findsOneWidget);

    // Sin cuenta recordada, pide entrar primero con "Recordarme".
    await tester.tap(find.byKey(const Key('login-huella')));
    await tester.pump();
    expect(find.textContaining('Recordarme'), findsWidgets);
    expect(find.text('Hola, Carlos'), findsNothing);
  });

  testWidgets('si la huella o el rostro no coincide, no entra',
      (WidgetTester tester) async {
    LocalAuthPlatform.instance =
        _BiometriaFalsa([BiometricType.weak], aprueba: false);
    SharedPreferences.setMockInitialValues({
      'recordar_correo': 'carlos@correo.com',
    });

    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('login-huella')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Carlos'), findsNothing);
    expect(find.text('Accede a tu cuenta'), findsOneWidget);
  });

  testWidgets('el botón de Google entra a Inicio', (WidgetTester tester) async {
    await _abrirLogin(tester);
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Carlos'), findsOneWidget);
  });

  testWidgets('el login valida el correo y la contraseña',
      (WidgetTester tester) async {
    await _abrirLogin(tester);

    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu correo electrónico'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'correo-malo');
    await tester.pumpAndSettle();
    expect(
      find.text('Escribe un correo válido, por ejemplo nombre@correo.com'),
      findsOneWidget,
    );
  });

  testWidgets('el login lleva a Inicio con los indicadores del portal',
      (WidgetTester tester) async {
    await _entrar(tester);

    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(find.text('MIS PEDIDOS-COTIZACIÓN'), findsOneWidget);
    expect(find.text('ESTADO DEL CRÉDITO'), findsOneWidget);
    expect(find.text('Mis Pedidos-Cotización Recientes'), findsOneWidget);
    expect(find.text('Llantas nuevas'), findsOneWidget);
  });

  testWidgets('la barra inferior navega y sigue visible en los detalles',
      (WidgetTester tester) async {
    await _entrar(tester);
    expect(find.byType(MiraNavBar), findsOneWidget);

    await _irA(tester, Icons.account_balance_wallet_outlined);
    expect(find.text('Mi cartera'), findsOneWidget);
    expect(find.text('MIS SOLICITUDES DE CRÉDITO'), findsOneWidget);

    await tester.tap(find.text('CRD-2025-001').first);
    await tester.pumpAndSettle();
    expect(find.text('Saldo pendiente'), findsOneWidget);
    // Aun dentro del detalle, la barra sigue en pantalla.
    expect(find.byType(MiraNavBar), findsOneWidget);

    // Ya no hay pestaña de Entregas: la barra tiene cuatro.
    expect(find.text('Entregas'), findsNothing);
    await _irA(tester, Icons.person_outline);
    expect(find.text('Mi perfil'), findsOneWidget);
  });

  testWidgets('las entregas se filtran por estado en Cotizaciones',
      (WidgetTester tester) async {
    await _entrar(tester);

    // "Próxima entrega" en Inicio abre Cotizaciones filtradas.
    await tester.tap(find.text('PRÓXIMA ENTREGA'));
    await tester.pumpAndSettle();
    expect(find.text('1 COTIZACIÓN'), findsOneWidget);
    expect(find.text('COT-2025-001'), findsOneWidget);

    // "Todas" de la fila de entrega quita el filtro.
    await tester.tap(find.text('Todas').last);
    await tester.pumpAndSettle();
    expect(find.text('6 COTIZACIONES'), findsOneWidget);

    // "Cancelado" queda al final de la fila de filtros: se desplaza hasta él.
    final chip = find.text('Cancelado').first;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('1 COTIZACIÓN'), findsOneWidget);
    expect(find.text('COT-2025-005'), findsOneWidget);
  });

  testWidgets('un abono queda pendiente hasta que el asesor lo valida',
      (WidgetTester tester) async {
    await _entrar(tester);
    final store = CarteraStore.instance;
    final credito = store.creditos[0];
    final saldoInicial = credito.saldo;

    await _irA(tester, Icons.account_balance_wallet_outlined);
    await tester.tap(find.text('CRD-2025-001').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();

    // Sin datos, el formulario avisa y no guarda.
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el monto abonado'), findsOneWidget);
    expect(find.text('Este campo es obligatorio'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '100000');
    await tester.pumpAndSettle();
    expect(find.text('100.000'), findsOneWidget);
    await tester.tap(find.text('Efectivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    expect(find.text('¡Abono registrado!'), findsOneWidget);
    // Como en la web: el saldo no baja hasta que se valida el pago.
    expect(credito.saldo, saldoInicial);
    expect(credito.abonos.first.estado, abonoPendiente);
    expect(credito.abonos.first.monto, 100000);

    await tester.tap(find.text('Volver a Cartera'));
    await tester.pumpAndSettle();
    expect(find.text('ABO-006 · \$ 100.000'), findsOneWidget);

    store.aprobarAbono(credito.abonos.first);
    expect(credito.saldo, saldoInicial - 100000);
  });

  testWidgets('la transferencia exige el pantallazo de la consignación',
      (WidgetTester tester) async {
    await _entrar(tester);
    final credito = CarteraStore.instance.creditos[0];
    final abonosAntes = credito.abonos.length;

    await _irA(tester, Icons.account_balance_wallet_outlined);
    await tester.tap(find.text('CRD-2025-001').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    expect(
      find.text('Adjunta el pantallazo de la consignación'),
      findsOneWidget,
    );
    expect(credito.abonos.length, abonosAntes);

    await tester.tap(find.byKey(const Key('abono-soporte')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abono-guardar')));
    await tester.pumpAndSettle();

    expect(find.text('¡Abono registrado!'), findsOneWidget);
    expect(credito.abonos.length, abonosAntes + 1);
    expect(credito.abonos.first.conComprobante, isTrue);
  });

  testWidgets('el abono mínimo es de 20.000 o el saldo exacto',
      (WidgetTester tester) async {
    final store = CarteraStore.instance;
    final credito = store.creditos[0];

    expect(store.errorMonto(credito, 0), 'Ingresa el monto abonado');
    expect(store.errorMonto(credito, 5000), contains('El abono mínimo'));
    expect(
      store.errorMonto(credito, credito.saldo + 1),
      'El monto supera el saldo pendiente',
    );
    expect(store.errorMonto(credito, 20000), isNull);
    expect(store.errorMonto(credito, credito.saldo), isNull);
  });

  testWidgets('el perfil se edita en la misma pantalla',
      (WidgetTester tester) async {
    await _entrar(tester);

    await _irA(tester, Icons.person_outline);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('CC 1023456789'), findsOneWidget);

    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar perfil'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('ACCESO'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);
  });

  testWidgets('una cotización formal se puede aceptar',
      (WidgetTester tester) async {
    await _entrar(tester);
    final cotizacion = CotizacionesStore.instance.porId('COT-2025-002')!;
    expect(cotizacion.etapa, 'Emitida');

    await _irA(tester, Icons.description_outlined);
    expect(find.text('6 COTIZACIONES'), findsOneWidget);

    // El filtro por etapa deja solo la cotización formal.
    await tester.tap(find.text('Emitida'));
    await tester.pumpAndSettle();
    expect(find.text('1 COTIZACIÓN'), findsOneWidget);
    expect(find.text('COT-2025-002'), findsOneWidget);

    await tester.tap(find.text('Aceptar cotización'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contado'));
    await tester.pumpAndSettle();

    expect(cotizacion.etapa, 'Aceptada');
    expect(cotizacion.metodoPago, 'Contado');
    expect(cotizacion.estadoPago, 'Pendiente');
  });

  testWidgets('el detalle de la cotización muestra productos y entrega',
      (WidgetTester tester) async {
    await _entrar(tester);

    await _irA(tester, Icons.description_outlined);
    await tester.tap(find.text('Ver detalle completo').first);
    await tester.pumpAndSettle();

    expect(find.text('Cotización COT-2025-001'), findsOneWidget);
    expect(find.text('PRODUCTOS Y SERVICIOS'), findsOneWidget);
    expect(find.text('ENTREGA'), findsOneWidget);
    expect(find.text('CRÉDITO CRD-2025-001'), findsOneWidget);
  });
}
