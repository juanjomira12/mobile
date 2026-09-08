// Prueba de humo del frontend: recorre splash -> login -> dashboards.
//
// Solo verifica la UI; la app no tiene backend ni autenticación real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirallantas/main.dart';

void main() {
  setUp(() => ThemeController.instance.value = ThemeMode.dark);

  // La superficie por defecto (800x600) no alcanza para el formulario:
  // se simula una pantalla de movil.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(420, 1400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('el splash da paso al login', (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());

    expect(find.text('MiraLlantas'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
  });

  testWidgets('entra al dashboard de usuario por defecto',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Ramírez'), findsOneWidget);
    expect(find.text('Saldo en crédito disponible'), findsOneWidget);
    expect(find.text('Reencauches'), findsNothing);
  });

  testWidgets('el rol Administrador lleva al dashboard de administrador',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Laura González'), findsOneWidget);
    expect(find.text('RESUMEN OPERATIVO DEL DÍA'), findsOneWidget);
    expect(find.text('Reencauches'), findsOneWidget);
  });

  testWidgets('el botón de tema alterna claro y oscuro',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.isDark, isTrue);
    await tester.tap(find.byIcon(Icons.light_mode_outlined).first);
    await tester.pumpAndSettle();
    expect(ThemeController.instance.isDark, isFalse);
  });

  testWidgets('los módulos abren cotizaciones, créditos y entregas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    // Cotizaciones: listado -> formulario de nueva cotización.
    await tester.tap(find.text('Cotizaciones').first);
    await tester.pumpAndSettle();
    expect(find.text('3 COTIZACIONES'), findsOneWidget);
    expect(find.text('COT-2025-001'), findsOneWidget);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cotización'), findsOneWidget);
    expect(find.text('PRODUCTOS DISPONIBLES'), findsOneWidget);
    expect(find.text('Michelin Energy XM2'), findsOneWidget);

    // El buscador filtra el catálogo.
    await tester.enterText(find.byType(TextField).first, 'reencauche');
    await tester.pumpAndSettle();
    expect(find.text('Michelin Energy XM2'), findsNothing);
    expect(find.text('Reencauche urbano'), findsOneWidget);

    // Agregar suma el producto al resumen de la cotización.
    await tester.tap(find.text('Agregar').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 × Reencauche'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Detalle de cotización.
    await tester.tap(find.text('COT-2025-002'));
    await tester.pumpAndSettle();
    expect(find.text('ÍTEMS DE LA COTIZACIÓN'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    // Créditos: listado -> detalle -> abono -> historial.
    await tester.tap(find.text('Créditos').first);
    await tester.pumpAndSettle();
    expect(find.text('Mis créditos'), findsOneWidget);

    await tester.tap(find.text('CRD-2025-001'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo pendiente'), findsOneWidget);

    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();
    expect(find.text('Método de pago'), findsOneWidget);
    expect(find.text('Daviplata'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();
    expect(find.text('Total abonado'), findsOneWidget);
    expect(find.text('TRANSACCIONES'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    // Entregas: listado -> detalle.
    await tester.tap(find.text('Entregas').first);
    await tester.pumpAndSettle();
    expect(find.text('3 ENTREGAS'), findsOneWidget);

    await tester.tap(find.text('ENT-001'));
    await tester.pumpAndSettle();
    expect(find.text('Estado de entrega'), findsOneWidget);
    expect(find.text('EVIDENCIA FOTOGRÁFICA'), findsOneWidget);
  });

  testWidgets('la barra inferior sigue visible en las pantallas internas',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(MiraTabBar), findsOneWidget);

    await tester.tap(find.text('Créditos').first);
    await tester.pumpAndSettle();
    expect(find.byType(MiraTabBar), findsOneWidget);

    await tester.tap(find.text('CRD-2025-001'));
    await tester.pumpAndSettle();
    expect(find.byType(MiraTabBar), findsOneWidget);

    // Desde una pantalla profunda, la barra lleva a otra pestaña.
    await tester.tap(find.text('Entregas').last);
    await tester.pumpAndSettle();
    expect(find.text('3 ENTREGAS'), findsOneWidget);
  });

  testWidgets('el perfil abre la pantalla de editar perfil',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiraLlantasApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mi Perfil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Carlos Ramírez'), findsOneWidget);
  });
}
