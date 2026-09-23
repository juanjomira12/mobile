// Pruebas de humo de la app: navegación, barra inferior y el único
// módulo con funcionalidad real (Cartera).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirallantas/main.dart';

/// Arranca la app y deja el splash atrás.
Future<void> _abrirLogin(WidgetTester tester) async {
  await tester.pumpWidget(const MiraLlantasApp());
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// La barra inferior solo muestra la etiqueta de la pestaña activa,
/// así que en las pruebas se toca por icono. El `.last` evita chocar con
/// los iconos iguales de las tarjetas de Inicio.
Future<void> _irA(WidgetTester tester, IconData icono) async {
  await tester.tap(find.byIcon(icono).last);
  await tester.pumpAndSettle();
}

/// Arranca la app y entra hasta Inicio.
Future<void> _entrar(WidgetTester tester) async {
  await _abrirLogin(tester);
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ThemeController.instance.set(false);
    // Las pruebas comparten el estado en memoria: se deja como al inicio.
    final store = CarteraStore.instance;
    store.carteras[0].abonado = 2100000;
    store.carteras[0].abonos.removeWhere((a) => a.metodo == 'Nequi');
    while (store.carteras[0].abonos.length > 4) {
      store.carteras[0].abonos.removeAt(0);
    }
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(420, 1500);
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

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    // La app es de un solo rol: ya no hay selector.
    expect(find.text('Administrador'), findsNothing);
  });

  testWidgets('el login lleva a Inicio con el resumen de cartera',
      (WidgetTester tester) async {
    await _entrar(tester);

    expect(find.text('Bienvenido de nuevo,'), findsOneWidget);
    expect(find.text('Saldo de Cartera disponible'), findsOneWidget);
    expect(find.text('Próximo pago'), findsOneWidget);
    expect(find.text('Llantas nuevas'), findsOneWidget);
  });

  testWidgets('la barra inferior navega y sigue visible en los detalles',
      (WidgetTester tester) async {
    await _entrar(tester);
    expect(find.byType(MiraNavBar), findsOneWidget);

    await _irA(tester, Icons.account_balance_wallet_outlined);
    expect(find.text('Mi Cartera'), findsOneWidget);

    await tester.tap(find.text('CRD-2025-001'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo pendiente'), findsOneWidget);
    // Aun dentro del detalle, la barra sigue en pantalla.
    expect(find.byType(MiraNavBar), findsOneWidget);

    await _irA(tester, Icons.local_shipping_outlined);
    expect(find.text('3 ENTREGAS'), findsOneWidget);
  });

  testWidgets('registrar un abono baja el saldo y queda en el historial',
      (WidgetTester tester) async {
    await _entrar(tester);
    final store = CarteraStore.instance;
    final pendienteInicial = store.carteras[0].pendiente;

    await _irA(tester, Icons.account_balance_wallet_outlined);
    await tester.tap(find.text('CRD-2025-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '100000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar abono'));
    await tester.pumpAndSettle();

    expect(find.text('¡Abono registrado!'), findsOneWidget);
    expect(store.carteras[0].pendiente, pendienteInicial - 100000);

    await tester.tap(find.text('Volver a Cartera'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CRD-2025-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();

    expect(find.text('Total abonado'), findsOneWidget);
    expect(find.text('\$ 100.000'), findsOneWidget);
  });

  testWidgets('el perfil se edita en la misma pantalla',
      (WidgetTester tester) async {
    await _entrar(tester);

    await _irA(tester, Icons.person_outline);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);
  });

  testWidgets('cotizaciones es solo visualización',
      (WidgetTester tester) async {
    await _entrar(tester);

    await _irA(tester, Icons.description_outlined);
    expect(find.text('3 COTIZACIONES'), findsOneWidget);

    await tester.tap(find.text('COT-2025-001'));
    await tester.pumpAndSettle();
    expect(find.text('ÍTEMS DE LA COTIZACIÓN'), findsOneWidget);
  });
}
