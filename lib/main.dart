// MiraLlantas — app móvil del cliente (solo UI).
//
// Todo vive en este archivo, por secciones:
//   1. Arranque y estado de Cartera (el único módulo con funcionalidad)
//   2. Tema: paleta, ThemeData y modo claro/oscuro
//   3. Widgets compartidos (cabecera, barra inferior animada, campos...)
//   4. Datos mock
//   5. Pantallas
//   6. Rutas
//
// Las secciones son las de la app (Inicio, Cotizaciones, Cartera, Entregas
// y Perfil), con el estilo, los estados y las reglas del portal web de
// MiraLlantas. Los datos son de ejemplo y viven en memoria: aceptar o
// cancelar una cotización y registrar un abono actualizan las pantallas,
// pero nada se envía todavía al servidor.

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MiraLlantasApp());

class MiraLlantasApp extends StatelessWidget {
  const MiraLlantasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MiraLlantas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          // El ambiente de color queda detrás de todas las pantallas: es lo
          // que el vidrio deja ver y desenfoca.
          builder: (context, child) =>
              FondoAmbiente(child: child ?? const SizedBox.shrink()),
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}

// ====================================================================
// 1. Estado en memoria: cartera y cotizaciones
// ====================================================================

/// Estados de un abono: queda pendiente hasta que un asesor lo valida.
const String abonoPendiente = 'Pendiente';
const String abonoAprobado = 'Aprobado';
const String abonoRechazado = 'Rechazado';

/// Condición de un crédito que todavía no arranca (falta la cuota inicial).
const String creditoSinIniciar = 'Pendiente de cuota inicial';

/// Medios con los que paga un cliente desde el portal.
const List<String> mediosPagoCliente = ['Efectivo', 'Transferencia'];

/// Abono mínimo, salvo que el saldo sea menor (se paga el saldo exacto).
const int abonoMinimo = 20000;

/// Un abono registrado sobre un crédito.
class Abono {
  Abono({
    required this.id,
    required this.credito,
    required this.monto,
    required this.fecha,
    required this.metodo,
    this.estado = abonoAprobado,
    this.motivoRechazo,
    this.conComprobante = false,
  });

  final String id;
  final String credito;
  final int monto;
  final String fecha;
  final String metodo;
  String estado;
  final String? motivoRechazo;

  /// `true` si el cliente adjuntó el pantallazo de la consignación.
  final bool conComprobante;
}

/// Crédito del cliente, tal como lo muestra "Mi cartera" en la web.
class Credito {
  Credito({
    required this.id,
    required this.cotizacion,
    required this.montoTotal,
    required this.saldo,
    required this.plazoDias,
    required this.fechaApertura,
    required this.fechaLimite,
    this.vencido = false,
    this.iniciado = true,
    List<Abono> abonos = const [],
  }) : abonos = List<Abono>.of(abonos);

  final String id;
  final String cotizacion;
  final int montoTotal;
  int saldo;
  final int plazoDias;
  final String fechaApertura;
  final String fechaLimite;
  final bool vencido;
  final bool iniciado;
  final List<Abono> abonos;

  int get abonado => (montoTotal - saldo).clamp(0, montoTotal);

  double get progreso =>
      montoTotal == 0 ? 0 : (abonado / montoTotal).clamp(0.0, 1.0);

  int get porcentaje => (progreso * 100).round();

  /// Abierto = todavía debe algo (o ni siquiera ha empezado).
  bool get abierto => !iniciado || saldo > 0;

  /// Cómo va el crédito hoy: se deduce del saldo y de la fecha límite.
  String get condicion {
    if (!iniciado) return creditoSinIniciar;
    if (saldo == 0) return 'Pagado';
    return vencido ? 'Vencido' : 'Al día';
  }

  bool get recibeAbonos => iniciado && saldo > 0;

  /// Suma de los abonos que el asesor ya validó.
  int get totalAprobado => abonos
      .where((a) => a.estado == abonoAprobado)
      .fold(0, (sum, a) => sum + a.monto);

  /// Un abono rechazado se vuelve a pedir mientras no haya otro posterior
  /// (pendiente o aprobado) que lo reemplace. La lista va del más nuevo
  /// al más viejo.
  bool pideReintento(Abono abono) {
    if (abono.estado != abonoRechazado) return false;
    final i = abonos.indexOf(abono);
    for (var j = 0; j < i; j++) {
      if (abonos[j].estado != abonoRechazado) return false;
    }
    return true;
  }
}

/// Solicitud de crédito hecha al aceptar una cotización.
class SolicitudCredito {
  const SolicitudCredito({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.plazoDias,
    required this.estado,
    this.cotizacion,
    this.motivo,
  });

  final String id;
  final int monto;
  final String fecha;
  final int plazoDias;
  final String estado;
  final String? cotizacion;
  final String? motivo;
}

/// Fecha de hoy en el formato de la web: AAAA-MM-DD.
String fechaHoy() {
  final now = DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${dos(now.month)}-${dos(now.day)}';
}

/// Estado en memoria de la cartera. Al registrar un abono, todas las
/// pantallas que escuchan este notificador se actualizan.
class CarteraStore extends ChangeNotifier {
  CarteraStore._() {
    reiniciar();
  }

  static final CarteraStore instance = CarteraStore._();

  final List<Credito> creditos = [];
  final List<SolicitudCredito> solicitudes = [];

  /// Deja los datos de ejemplo como al abrir la app.
  void reiniciar() {
    creditos
      ..clear()
      ..addAll([
        Credito(
          id: 'CRD-2025-001',
          cotizacion: 'COT-2025-001',
          montoTotal: 840000,
          saldo: 490000,
          plazoDias: 90,
          fechaApertura: '2025-07-16',
          fechaLimite: '2025-10-14',
          abonos: [
            Abono(
              id: 'ABO-005',
              credito: 'CRD-2025-001',
              monto: 150000,
              fecha: '2025-09-02',
              metodo: 'Transferencia',
              estado: abonoPendiente,
              conComprobante: true,
            ),
            Abono(
              id: 'ABO-004',
              credito: 'CRD-2025-001',
              monto: 200000,
              fecha: '2025-08-15',
              metodo: 'Transferencia',
              estado: abonoRechazado,
              motivoRechazo:
                  'El valor del comprobante no coincide con el monto.',
              conComprobante: true,
            ),
            Abono(
              id: 'ABO-003',
              credito: 'CRD-2025-001',
              monto: 350000,
              fecha: '2025-08-01',
              metodo: 'Efectivo',
            ),
          ],
        ),
        Credito(
          id: 'CRD-2025-002',
          cotizacion: 'COT-2025-004',
          montoTotal: 630000,
          saldo: 0,
          plazoDias: 60,
          fechaApertura: '2025-05-12',
          fechaLimite: '2025-07-11',
          abonos: [
            Abono(
              id: 'ABO-002',
              credito: 'CRD-2025-002',
              monto: 330000,
              fecha: '2025-06-28',
              metodo: 'Transferencia',
              conComprobante: true,
            ),
            Abono(
              id: 'ABO-001',
              credito: 'CRD-2025-002',
              monto: 300000,
              fecha: '2025-06-05',
              metodo: 'Efectivo',
            ),
          ],
        ),
      ]);
    solicitudes
      ..clear()
      ..addAll(const [
        SolicitudCredito(
          id: 'SOL-002',
          monto: 840000,
          fecha: '2025-07-15',
          plazoDias: 90,
          estado: 'Aprobada',
          cotizacion: 'COT-2025-001',
        ),
        SolicitudCredito(
          id: 'SOL-001',
          monto: 630000,
          fecha: '2025-05-10',
          plazoDias: 60,
          estado: 'Aprobada',
          cotizacion: 'COT-2025-004',
        ),
      ]);
    _consecutivo = 5;
    notifyListeners();
  }

  int _consecutivo = 5;

  /// Solo se puede tener un crédito abierto a la vez.
  bool get tieneCredito => creditos.any((c) => c.abierto);

  /// Lo comprometido en créditos abiertos.
  int get saldoPendiente =>
      creditos.where((c) => c.abierto).fold(0, (sum, c) => sum + c.saldo);

  Credito? porId(String? id) {
    for (final c in creditos) {
      if (c.id == id) return c;
    }
    return null;
  }

  Credito? deCotizacion(String cotizacion) {
    for (final c in creditos) {
      if (c.cotizacion == cotizacion) return c;
    }
    return null;
  }

  /// `null` si el monto sirve; si no, el aviso que se le muestra al cliente.
  String? errorMonto(Credito credito, int monto) {
    if (monto <= 0) return 'Ingresa el monto abonado';
    if (monto > credito.saldo) return 'El monto supera el saldo pendiente';
    if (monto < abonoMinimo && monto != credito.saldo) {
      return 'El abono mínimo es de ${formatCop(abonoMinimo)} '
          '(o paga el saldo exacto de ${formatCop(credito.saldo)})';
    }
    return null;
  }

  /// Registra un abono. Igual que en la web, queda **pendiente** hasta que
  /// un asesor lo valide: el saldo no baja todavía.
  Abono registrarAbono({
    required Credito credito,
    required int monto,
    required String metodo,
    bool conComprobante = false,
  }) {
    _consecutivo++;
    final abono = Abono(
      id: 'ABO-${_consecutivo.toString().padLeft(3, '0')}',
      credito: credito.id,
      monto: monto,
      fecha: fechaHoy(),
      metodo: metodo,
      estado: abonoPendiente,
      conComprobante: conComprobante,
    );
    credito.abonos.insert(0, abono);
    notifyListeners();
    return abono;
  }

  /// Lo que hace el asesor en el panel: valida el abono y baja el saldo.
  /// La app no lo ofrece al cliente; lo usan las pruebas.
  void aprobarAbono(Abono abono) {
    final credito = porId(abono.credito);
    if (credito == null || abono.estado != abonoPendiente) return;
    abono.estado = abonoAprobado;
    credito.saldo = (credito.saldo - abono.monto).clamp(0, credito.montoTotal);
    notifyListeners();
  }
}

/// Renglón de una cotización: un producto (llanta) o un servicio.
class LineaCotizacion {
  const LineaCotizacion({
    required this.nombre,
    required this.medida,
    required this.cantidad,
    this.valorUnitario,
    this.esServicio = false,
  });

  final String nombre;
  final String medida;
  final int cantidad;

  /// `null` mientras el asesor confirma el precio con el proveedor.
  final int? valorUnitario;
  final bool esServicio;

  int get subtotal => cantidad * (valorUnitario ?? 0);
}

/// Cotización-pedido del cliente, con las mismas etapas y estados de la web.
class Cotizacion {
  Cotizacion({
    required this.id,
    required this.fecha,
    required this.etapa,
    required this.estado,
    required this.estadoEntrega,
    required this.direccion,
    required this.lineas,
    this.estadoPago,
    this.metodoPago,
    this.emitidaEn,
    this.venceEn,
    this.motivoCancelacion,
  });

  final String id;
  final String fecha;

  /// Solicitud · Emitida · Vencida · Aceptada
  String etapa;

  /// Pendiente · En proceso · Completada · Rechazada
  String estado;

  /// Pendiente · En camino · Entregado · Cancelado
  String estadoEntrega;

  /// Pendiente · Aprobado · Rechazado (o `null` si aún no hay pago)
  String? estadoPago;

  /// Contado · Crédito (se elige al aceptar la cotización)
  String? metodoPago;
  final String direccion;
  final String? emitidaEn;
  final String? venceEn;
  String? motivoCancelacion;
  final List<LineaCotizacion> lineas;

  int get total => lineas.fold(0, (sum, l) => sum + l.subtotal);

  int get totalServicios =>
      lineas.where((l) => l.esServicio).fold(0, (sum, l) => sum + l.subtotal);

  bool get conServicios => totalServicios > 0;

  int get llantas => lineas.fold(0, (sum, l) => sum + l.cantidad);

  /// En "Solicitud" todavía no hay precios formales.
  String get totalTexto =>
      etapa == 'Solicitud' ? 'Por confirmar' : formatCop(total);

  /// Mientras no la acepte, el cliente puede cancelarla.
  bool get cancelable => estado == 'Pendiente' && etapa != 'Aceptada';

  String get etapaTexto => switch (etapa) {
        'Solicitud' => 'Precios por confirmar',
        'Emitida' => 'Cotización formal',
        _ => etapa,
      };
}

/// Vigencia de una cotización formal y plazo de respuesta del asesor.
const int vigenciaCotizacionDias = 8;
const int plazoRespuestaHoras = 24;

/// Cotizaciones del cliente (en memoria). Aceptar o cancelar una
/// cotización avisa a las pantallas que la muestran.
class CotizacionesStore extends ChangeNotifier {
  CotizacionesStore._() {
    reiniciar();
  }

  static final CotizacionesStore instance = CotizacionesStore._();

  final List<Cotizacion> cotizaciones = [];

  void reiniciar() {
    const direccion = 'Cra. 45 #80-23, Medellín';
    cotizaciones
      ..clear()
      ..addAll([
        Cotizacion(
          id: 'COT-2025-001',
          fecha: '2025-07-15',
          etapa: 'Aceptada',
          estado: 'En proceso',
          estadoEntrega: 'En camino',
          estadoPago: 'Aprobado',
          metodoPago: 'Crédito',
          direccion: direccion,
          emitidaEn: '2025-07-15',
          venceEn: '2025-07-23',
          lineas: const [
            LineaCotizacion(
              nombre: 'Llanta Michelin Energy XM2',
              medida: '205/65R15',
              cantidad: 4,
              valorUnitario: 280000,
            ),
            LineaCotizacion(
              nombre: 'Instalación y balanceo',
              medida: '205/65R15',
              cantidad: 4,
              valorUnitario: 20000,
              esServicio: true,
            ),
          ],
        ),
        Cotizacion(
          id: 'COT-2025-002',
          fecha: '2025-07-22',
          etapa: 'Emitida',
          estado: 'Pendiente',
          estadoEntrega: 'Pendiente',
          direccion: 'Cl. 10 #5-67, El Poblado',
          emitidaEn: '2025-07-23',
          venceEn: '2025-07-31',
          lineas: const [
            LineaCotizacion(
              nombre: 'Reencauche de llanta',
              medida: '295/80R22.5',
              cantidad: 3,
              valorUnitario: 150000,
              esServicio: true,
            ),
          ],
        ),
        Cotizacion(
          id: 'COT-2025-003',
          fecha: '2025-08-03',
          etapa: 'Solicitud',
          estado: 'Pendiente',
          estadoEntrega: 'Pendiente',
          direccion: direccion,
          lineas: const [
            LineaCotizacion(
              nombre: 'Llanta Bridgestone Turanza',
              medida: '225/45R17',
              cantidad: 2,
            ),
          ],
        ),
        Cotizacion(
          id: 'COT-2025-004',
          fecha: '2025-05-10',
          etapa: 'Aceptada',
          estado: 'Completada',
          estadoEntrega: 'Entregado',
          estadoPago: 'Aprobado',
          metodoPago: 'Crédito',
          direccion: direccion,
          emitidaEn: '2025-05-10',
          venceEn: '2025-05-18',
          lineas: const [
            LineaCotizacion(
              nombre: 'Llanta Pirelli FR85',
              medida: '11R22.5',
              cantidad: 2,
              valorUnitario: 450000,
            ),
          ],
        ),
        Cotizacion(
          id: 'COT-2025-005',
          fecha: '2025-08-06',
          etapa: 'Aceptada',
          estado: 'Rechazada',
          estadoEntrega: 'Cancelado',
          estadoPago: 'Pendiente',
          metodoPago: 'Contado',
          direccion: 'Av. El Dorado #68C-61, Bogotá',
          emitidaEn: '2025-08-06',
          venceEn: '2025-08-14',
          motivoCancelacion:
              'Cliente solicitó cancelación por cambio de domicilio.',
          lineas: const [
            LineaCotizacion(
              nombre: 'Llanta Bridgestone Dueler',
              medida: '265/70R16',
              cantidad: 4,
              valorUnitario: 520000,
            ),
          ],
        ),
        Cotizacion(
          id: 'COT-2025-006',
          fecha: '2025-04-20',
          etapa: 'Vencida',
          estado: 'Pendiente',
          estadoEntrega: 'Pendiente',
          direccion: direccion,
          emitidaEn: '2025-04-21',
          venceEn: '2025-04-29',
          lineas: const [
            LineaCotizacion(
              nombre: 'Llanta Michelin X Multi',
              medida: '295/80R22.5',
              cantidad: 2,
              valorUnitario: 1350000,
            ),
          ],
        ),
      ]);
    notifyListeners();
  }

  Cotizacion? porId(String id) {
    for (final c in cotizaciones) {
      if (c.id == id) return c;
    }
    return null;
  }

  int get pendientes =>
      cotizaciones.where((c) => c.estado == 'Pendiente').length;

  /// Total de lo ya comprado (cotizaciones completadas).
  int get totalComprado => cotizaciones
      .where((c) => c.estado == 'Completada')
      .fold(0, (sum, c) => sum + c.total);

  /// Las de crédito encabezan, como en la web.
  List<Cotizacion> get ordenadas {
    final cartera = CarteraStore.instance;
    final conCredito = <Cotizacion>[];
    final sinCredito = <Cotizacion>[];
    for (final c in cotizaciones) {
      (cartera.deCotizacion(c.id) != null ? conCredito : sinCredito).add(c);
    }
    return [...conCredito, ...sinCredito];
  }

  /// Acepta la cotización formal: el cliente elige contado o crédito y el
  /// pago queda pendiente de validación.
  void aceptar(Cotizacion cotizacion, String metodoPago) {
    if (cotizacion.etapa != 'Emitida') return;
    cotizacion
      ..etapa = 'Aceptada'
      ..metodoPago = metodoPago
      ..estadoPago = 'Pendiente';
    notifyListeners();
  }

  /// Cancela una cotización que todavía no se ha aceptado (no se borra).
  void cancelar(Cotizacion cotizacion, String motivo) {
    if (!cotizacion.cancelable) return;
    cotizacion
      ..estado = 'Rechazada'
      ..estadoEntrega = 'Cancelado'
      ..motivoCancelacion = motivo;
    notifyListeners();
  }
}

// ====================================================================
// 2. Tema
// ====================================================================

class AppColors {
  const AppColors._();

  // Identidad cromática de la web (frontend/tailwind.config.js):
  //   Azul industrial #17375E · Amarillo marca #F4C400 · Carbón #24282D
  static const Color accent = Color(0xFFF4C400);
  static const Color accentDark = Color(0xFFA68500);
  static const Color onAccent = Color(0xFF24282D);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color violeta = Color(0xFF7C3AED);

  /// Azul medianoche del splash y del panel de marca.
  static const Color navy900 = Color(0xFF081426);

  static const MiraPalette dark = MiraPalette(
    background: Color(0xFF081426),
    surface: Color(0xFF0E2140),
    surfaceAlt: Color(0xFF132A4E),
    header: Color(0xFF0E2140),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xBFFFFFFF),
    headerOverlay: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0x1FFFFFFF),
    inputFill: Color(0xFF0B1B34),
    iconTileBg: Color(0xFF17375E),
    iconTileFg: Color(0xFF8FB4E3),
    trackBg: Color(0x1FFFFFFF),
    accentSoft: Color(0x26F4C400),
    successSoft: Color(0x2610B981),
    warningSoft: Color(0x26F59E0B),
    dangerSoft: Color(0x26EF4444),
    infoSoft: Color(0x263B82F6),
    violetaSoft: Color(0x268B5CF6),
    successFg: Color(0xFF34D399),
    warningFg: Color(0xFFF4C400),
    dangerFg: Color(0xFFF87171),
    infoFg: Color(0xFF60A5FA),
    violetaFg: Color(0xFFA78BFA),
    shadow: Color(0x66000000),
    link: Color(0xFFF4C400),
    isDark: true,
  );

  static const MiraPalette light = MiraPalette(
    background: Color(0xFFF3F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F9),
    header: Color(0xFF17375E),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xCCFFFFFF),
    headerOverlay: Color(0x29FFFFFF),
    textPrimary: Color(0xFF24282D),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    inputFill: Color(0xFFFFFFFF),
    iconTileBg: Color(0xFFE2E8F1),
    iconTileFg: Color(0xFF17375E),
    trackBg: Color(0xFFE2E8F0),
    accentSoft: Color(0x26F4C400),
    successSoft: Color(0x2610B981),
    warningSoft: Color(0x26F59E0B),
    dangerSoft: Color(0x1FEF4444),
    infoSoft: Color(0x263B82F6),
    violetaSoft: Color(0x268B5CF6),
    successFg: Color(0xFF059669),
    warningFg: Color(0xFFA68500),
    dangerFg: Color(0xFFDC2626),
    infoFg: Color(0xFF2563EB),
    violetaFg: Color(0xFF7C3AED),
    shadow: Color(0x1A17375E),
    link: Color(0xFFA68500),
    isDark: false,
  );
}

@immutable
class MiraPalette extends ThemeExtension<MiraPalette> {
  const MiraPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.header,
    required this.onHeader,
    required this.onHeaderMuted,
    required this.headerOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.inputFill,
    required this.iconTileBg,
    required this.iconTileFg,
    required this.trackBg,
    required this.accentSoft,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.infoSoft,
    required this.violetaSoft,
    required this.successFg,
    required this.warningFg,
    required this.dangerFg,
    required this.infoFg,
    required this.violetaFg,
    required this.shadow,
    required this.link,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color header;
  final Color onHeader;
  final Color onHeaderMuted;
  final Color headerOverlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color inputFill;
  final Color iconTileBg;
  final Color iconTileFg;
  final Color trackBg;
  final Color accentSoft;
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color infoSoft;
  final Color violetaSoft;
  final Color successFg;
  final Color warningFg;
  final Color dangerFg;
  final Color infoFg;
  final Color violetaFg;
  final Color shadow;
  final Color link;
  final bool isDark;

  @override
  MiraPalette copyWith() => this;

  @override
  MiraPalette lerp(ThemeExtension<MiraPalette>? other, double t) {
    if (other is! MiraPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension MiraThemeContext on BuildContext {
  MiraPalette get palette => Theme.of(this).extension<MiraPalette>()!;
}

/// Controla el modo claro/oscuro (en memoria, sin persistencia).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  bool get isDark => value == ThemeMode.dark;

  void toggle() => value = isDark ? ThemeMode.light : ThemeMode.dark;

  void set(bool dark) => value = dark ? ThemeMode.dark : ThemeMode.light;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(MiraPalette p, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    final scheme = base.copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: p.header,
      onSecondary: p.onHeader,
      error: AppColors.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      outline: p.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      extensions: <ThemeExtension<dynamic>>[p],
      textTheme: _textTheme(p),
      iconTheme: IconThemeData(color: p.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(p.border),
        enabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(AppColors.accent, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: p.trackBg,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.isDark ? p.textPrimary : p.header,
          backgroundColor: p.surface,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: p.isDark ? p.textMuted : p.header),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.link,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.header,
        contentTextStyle: TextStyle(color: p.onHeader),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: p.trackBg,
      ),
    );
  }

  static TextTheme _textTheme(MiraPalette p) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: p.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: p.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: p.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: p.textMuted, fontSize: 12.5),
      labelLarge: TextStyle(
        color: p.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: p.textMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

// ====================================================================
// 3. Widgets compartidos
// ====================================================================

/// `1200000` -> `$ 1.200.000`
String formatCop(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}\$ $buffer';
}

/// Botón cuadrado de sol/luna de las cabeceras.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.isDark ? const Color(0x1AFFFFFF) : const Color(0x1417375E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: ThemeController.instance.toggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            palette.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: palette.textPrimary,
            size: 21,
          ),
        ),
      ),
    );
  }
}

/// Cabecera azul marino: título, volver opcional y botón de tema.
class MiraHeader extends StatelessWidget {
  const MiraHeader({
    super.key,
    required this.title,
    this.showBack,
    this.subtitle,
  });

  final String title;

  /// `null` = se muestra solo si hay una ruta a la que volver.
  final bool? showBack;

  /// Línea pequeña encima del título (el saludo de Inicio).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final canBack = showBack ?? Navigator.of(context).canPop();

    return Vidrio(
      sombra: false,
      soloBordeInferior: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canBack ? 8 : 20, 10, 12, 14),
          child: Row(
            children: [
              if (canBack)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_ios_new,
                      size: 20, color: palette.textPrimary),
                  tooltip: 'Volver',
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: palette.textSecondary),
                      ),
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        letterSpacing: -0.3,
                        fontSize: subtitle == null ? 20 : 22,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeToggleButton(),
            ],
          ),
        ),
      ),
    );
  }
}

enum EstadoTono { exito, aviso, error, info, violeta, neutro }

const Set<String> _estadosVerdes = {
  'Aprobado', 'Entregado', 'Completado', 'Recibida', 'Confirmado', 'Al día',
  'Disponible', 'Pagado', 'Apta', 'Aprobada', 'Completada', 'Activo',
  'Aceptada',
};

const Set<String> _estadosAmbar = {
  'Solicitud', 'Pendiente', 'En proceso', 'En tránsito', 'En camino',
  'Por entregar', 'Pendiente de revisión', creditoSinIniciar,
};

const Set<String> _estadosRojos = {
  'Vencida', 'Rechazado', 'Vencido', 'Cancelado', 'Rechazada', 'No apta',
  'Anulada',
};

const Set<String> _estadosAzules = {'Emitida', 'Contado', 'Neutral'};

/// Mismo código de colores que el `Badge` de la web: verde = listo,
/// ámbar = en curso, rojo = rechazado o vencido, azul = informativo.
EstadoTono tonoDeEstado(String estado) {
  if (_estadosVerdes.contains(estado)) return EstadoTono.exito;
  if (_estadosAmbar.contains(estado)) return EstadoTono.aviso;
  if (_estadosRojos.contains(estado)) return EstadoTono.error;
  if (_estadosAzules.contains(estado)) return EstadoTono.info;
  if (estado == 'Crédito') return EstadoTono.violeta;
  return EstadoTono.neutro;
}

/// Color de texto y de fondo de cada tono, según el tema.
(Color, Color) coloresDeTono(MiraPalette palette, EstadoTono tono) {
  return switch (tono) {
    EstadoTono.exito => (palette.successFg, palette.successSoft),
    EstadoTono.aviso => (palette.warningFg, palette.warningSoft),
    EstadoTono.error => (palette.dangerFg, palette.dangerSoft),
    EstadoTono.info => (palette.infoFg, palette.infoSoft),
    EstadoTono.violeta => (palette.violetaFg, palette.violetaSoft),
    EstadoTono.neutro => (palette.textSecondary, palette.surfaceAlt),
  };
}

/// Pastilla de estado (Aprobado, Al día, En camino...).
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.label, required this.tono});

  /// El tono sale del propio texto, como en la web. `estado` permite que
  /// la etiqueta visible sea distinta del estado que da el color.
  EstadoChip.de(this.label, {super.key, String? estado})
      : tono = tonoDeEstado(estado ?? label);

  final String label;
  final EstadoTono tono;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = coloresDeTono(context.palette, tono);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Indicador del tablero: etiqueta, valor grande, detalle e icono de color.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    this.tono = EstadoTono.aviso,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final EstadoTono tono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color fg, Color bg) = coloresDeTono(context.palette, tono);
    return MiraCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 10.5, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineLarge?.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Caja de aviso con borde y fondo del color del tono.
class AvisoCaja extends StatelessWidget {
  const AvisoCaja({
    super.key,
    required this.texto,
    this.tono = EstadoTono.aviso,
    this.icon,
  });

  final String texto;
  final EstadoTono tono;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = coloresDeTono(context.palette, tono);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cajita gris con etiqueta en mayúsculas y valor (MONTO, SALDO, PLAZO...).
class CajaDato extends StatelessWidget {
  const CajaDato({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontSize: 10, letterSpacing: 0.6),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Cuatro cajas de datos en rejilla de 2 × 2.
class RejillaDatos extends StatelessWidget {
  const RejillaDatos({super.key, required this.datos});

  final List<(String, String)> datos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < datos.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CajaDato(label: datos[i].$1, value: datos[i].$2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < datos.length
                    ? CajaDato(label: datos[i + 1].$1, value: datos[i + 1].$2)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Título y bajada de una pantalla raíz, como los `h1` del portal web.
class TituloPagina extends StatelessWidget {
  const TituloPagina({super.key, required this.titulo, required this.bajada});

  final String titulo;
  final String bajada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: theme.textTheme.headlineLarge?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text(bajada, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Pasos del despacho, en orden.
const List<String> pasosEntrega = ['Pendiente', 'En camino', 'Entregado'];

/// Seguimiento de la entrega: los pasos cumplidos van en verde.
class PasosEntrega extends StatelessWidget {
  const PasosEntrega({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final actual = pasosEntrega.indexOf(estado);
    return Column(
      children: [
        for (var i = 0; i < pasosEntrega.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= actual ? palette.successFg : Colors.transparent,
                    border: i <= actual
                        ? null
                        : Border.all(color: palette.textMuted),
                  ),
                  child: i <= actual
                      ? Icon(Icons.check, size: 14, color: palette.surface)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.textMuted,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  pasosEntrega[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        i <= actual ? palette.textPrimary : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Aviso corto en la parte inferior de la pantalla.
void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Correo con formato mínimo válido (misma regla del login web).
final RegExp _correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? errorCorreo(String correo) {
  final c = correo.trim();
  if (c.isEmpty) return 'Escribe tu correo electrónico';
  if (!_correoValido.hasMatch(c)) {
    return 'Escribe un correo válido, por ejemplo nombre@correo.com';
  }
  return null;
}

/// Texto de ayuda bajo el campo de contraseña.
const String ayudaPassword = 'Mínimo 10 caracteres, con letras y números.';

/// Misma regla de contraseña que aplica la web.
String? errorPassword(String password) {
  if (password.length < 10 ||
      !RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'[0-9]').hasMatch(password)) {
    return ayudaPassword;
  }
  return null;
}

/// Escribe el monto con puntos de miles mientras se digita: 1.200.000
class MilesFormatter extends TextInputFormatter {
  const MilesFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const TextEditingValue();
    // Hasta 12 cifras: de sobra para un monto en pesos.
    final recorte = digitos.length > 12 ? digitos.substring(0, 12) : digitos;
    final texto = formatCop(int.parse(recorte)).substring(2);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// `1.200.000` -> 1200000
int parseCop(String texto) =>
    int.tryParse(texto.replaceAll(RegExp(r'\D'), '')) ?? 0;

/// Ambiente de color de la web (`.ml-ambiente`): manchas suaves de azul
/// industrial y amarillo de marca sobre el fondo. Sin él, el vidrio no
/// tendría nada que dejar ver.
class FondoAmbiente extends StatelessWidget {
  const FondoAmbiente({super.key, required this.child});

  final Widget child;

  static const Color _azul = Color(0xFF17375E);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = palette.isDark;

    BoxDecoration mancha(Alignment centro, double radio, Color color) {
      return BoxDecoration(
        gradient: RadialGradient(
          center: centro,
          radius: radio,
          colors: [color, color.withAlpha(0)],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.background),
      child: DecoratedBox(
        decoration: mancha(
          const Alignment(-1.2, -1.15),
          dark ? 1.25 : 1.1,
          _azul.withAlpha(dark ? 200 : 46),
        ),
        child: DecoratedBox(
          decoration: mancha(
            const Alignment(1.25, -1.0),
            0.9,
            AppColors.accent.withAlpha(dark ? 22 : 40),
          ),
          child: DecoratedBox(
            decoration: mancha(
              const Alignment(0.3, 1.3),
              1.0,
              _azul.withAlpha(dark ? 100 : 26),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Lámina de vidrio: desenfoca lo que tiene detrás, lo tiñe con un relleno
/// translúcido y lleva un filo claro arriba, como la luz sobre el material.
/// Se reserva para lo que flota (cabecera, barra inferior, diálogos): las
/// tarjetas del contenido son translúcidas pero no desenfocan, para que
/// una lista larga se siga desplazando con fluidez.
///
/// Con "más contraste" activado en el sistema, el vidrio se vuelve sólido.
class Vidrio extends StatelessWidget {
  const Vidrio({
    super.key,
    required this.child,
    this.radius = BorderRadius.zero,
    this.blur = 24,
    this.sombra = true,
    this.soloBordeInferior = false,
  });

  final Widget child;
  final BorderRadius radius;
  final double blur;
  final bool sombra;

  /// Para la cabecera: solo una línea fina abajo en vez del contorno.
  final bool soloBordeInferior;

  /// Relleno translúcido de las superficies de vidrio, según el tema.
  static Color relleno(MiraPalette palette, {double densidad = 1}) {
    final base = palette.isDark ? const Color(0xFF0A1A30) : Colors.white;
    final alpha = ((palette.isDark ? 150 : 168) * densidad).round();
    return base.withAlpha(alpha.clamp(0, 255));
  }

  /// Filo claro del vidrio.
  static Color filo(MiraPalette palette) =>
      palette.isDark ? const Color(0x1FFFFFFF) : const Color(0xE6FFFFFF);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final solido = MediaQuery.highContrastOf(context);
    final fondo = solido ? palette.surface : relleno(palette);
    final brillo = palette.isDark
        ? const Color(0xFF17375E).withAlpha(solido ? 0 : 90)
        : Colors.white.withAlpha(solido ? 0 : 120);
    final linea = solido ? palette.textMuted : filo(palette);

    final Widget lamina = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(brillo, fondo), fondo],
          stops: const [0, 0.6],
        ),
        border: soloBordeInferior
            ? Border(bottom: BorderSide(color: palette.border))
            : Border.all(color: linea),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: sombra
            ? [
                BoxShadow(
                  color: palette.isDark
                      ? const Color(0x73000000)
                      : const Color(0x2617375E),
                  blurRadius: 28,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: solido
            ? lamina
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: lamina,
              ),
      ),
    );
  }
}

/// Reflejo que sigue el dedo: mientras se toca o se arrastra sobre la
/// superficie, una mancha de luz aclara el vidrio justo debajo, como si se
/// viera a través de él. Aparece al instante al tocar y se apaga con
/// suavidad al soltar.
///
/// Solo escucha el puntero (no compite con los toques ni con el
/// desplazamiento) y se pinta encima sin cambiar el tamaño del hijo.
class ReflejoTactil extends StatefulWidget {
  const ReflejoTactil({
    super.key,
    required this.child,
    this.radius = BorderRadius.zero,
    this.tamano = 150,
  });

  final Widget child;
  final BorderRadius radius;

  /// Radio de la mancha de luz, en píxeles lógicos.
  final double tamano;

  @override
  State<ReflejoTactil> createState() => _ReflejoTactilState();
}

class _ReflejoTactilState extends State<ReflejoTactil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _luz = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 520),
  );

  final ValueNotifier<Offset> _punto = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _luz.dispose();
    _punto.dispose();
    super.dispose();
  }

  void _encender(PointerEvent e) {
    _punto.value = e.localPosition;
    _luz.forward();
  }

  void _apagar(PointerEvent e) => _luz.reverse();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Con "más contraste" o "reducir movimiento" no hay reflejo.
    if (MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: _encender,
      onPointerMove: _encender,
      onPointerUp: _apagar,
      onPointerCancel: _apagar,
      child: CustomPaint(
        foregroundPainter: _PintorReflejo(
          punto: _punto,
          luz: CurvedAnimation(
            parent: _luz,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          radius: widget.radius,
          tamano: widget.tamano,
          color: palette.isDark
              ? const Color(0x38FFFFFF)
              : const Color(0xCCFFFFFF),
          tinte: AppColors.accent.withAlpha(palette.isDark ? 30 : 46),
        ),
        child: widget.child,
      ),
    );
  }
}

class _PintorReflejo extends CustomPainter {
  _PintorReflejo({
    required this.punto,
    required this.luz,
    required this.radius,
    required this.tamano,
    required this.color,
    required this.tinte,
  }) : super(repaint: Listenable.merge([punto, luz]));

  final ValueNotifier<Offset> punto;
  final Animation<double> luz;
  final BorderRadius radius;
  final double tamano;
  final Color color;
  final Color tinte;

  @override
  void paint(Canvas canvas, Size size) {
    final fuerza = luz.value;
    if (fuerza <= 0) return;

    final centro = punto.value;
    Color atenuar(Color c) => c.withAlpha((c.a * 255 * fuerza).round());

    canvas.save();
    canvas.clipRRect(radius.toRRect(Offset.zero & size));
    // Halo amplio con un toque del amarillo de marca...
    canvas.drawCircle(
      centro,
      tamano,
      Paint()
        ..shader = RadialGradient(
          colors: [atenuar(tinte), tinte.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: centro, radius: tamano)),
    );
    // ...y, dentro, el brillo más claro justo bajo el dedo.
    final nucleo = tamano * 0.62;
    canvas.drawCircle(
      centro,
      nucleo,
      Paint()
        ..shader = RadialGradient(
          colors: [atenuar(color), color.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: centro, radius: nucleo)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorReflejo old) =>
      old.color != color ||
      old.tinte != tinte ||
      old.radius != radius ||
      old.tamano != tamano;
}

/// Margen de las pantallas con lista. La barra inferior flota sobre el
/// contenido, así que abajo se suma el espacio que ocupa para que lo
/// último de la lista no quede tapado.
EdgeInsets margenPagina(
  BuildContext context, {
  double top = 16,
  double lado = 16,
  double bottom = 20,
}) {
  return EdgeInsets.fromLTRB(
    lado,
    top,
    lado,
    bottom + MediaQuery.paddingOf(context).bottom,
  );
}

/// Tarjeta estándar de toda la app: translúcida, con filo claro.
class MiraCard extends StatelessWidget {
  const MiraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlight = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Contorno marcado del color del estado (crédito al día, vencido...).
  final Color? borderColor;

  /// Borde amarillo para las tarjetas destacadas de Inicio.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final solido = MediaQuery.highContrastOf(context);
    final decoration = BoxDecoration(
      color: solido
          ? palette.surface
          : Vidrio.relleno(palette, densidad: palette.isDark ? 0.85 : 1.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ??
            (highlight
                ? AppColors.accent
                : (solido ? palette.border : Vidrio.filo(palette))),
        width: borderColor != null && borderColor != palette.border
            ? 2
            : (highlight ? 1.4 : 1),
      ),
      boxShadow: palette.isDark
          ? null
          : [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
    );

    final radio = BorderRadius.circular(20);
    if (onTap == null) {
      return ReflejoTactil(
        radius: radio,
        child: Container(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      );
    }
    return ReflejoTactil(
      radius: radio,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radio,
          // El reflejo ya responde al toque: sin onda ni mancha gris.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Ink(
            padding: padding,
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pestañas de la barra inferior.
enum MiraTab { inicio, cotizaciones, cartera, perfil }

const List<({IconData icon, IconData active, String label})> _tabItems = [
  (icon: Icons.home_outlined, active: Icons.home, label: 'Inicio'),
  (
    icon: Icons.description_outlined,
    active: Icons.description,
    label: 'Cotizaciones'
  ),
  (
    icon: Icons.account_balance_wallet_outlined,
    active: Icons.account_balance_wallet,
    label: 'Cartera'
  ),
  (icon: Icons.person_outline, active: Icons.person, label: 'Perfil'),
];

/// Barra inferior flotante: el círculo amarillo se desliza hasta la
/// pestaña elegida y sobresale de la barra, con el icono saltando dentro
/// mientras la etiqueta se queda abajo.
class MiraNavBar extends StatelessWidget {
  const MiraNavBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final MiraTab current;
  final ValueChanged<MiraTab> onSelected;

  static const double alto = 68;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final index = current.index;
    // -1 = primera pestaña, 1 = última; el resto queda repartido.
    final x = -1 + 2 * index / (_tabItems.length - 1);

    return SafeArea(
      top: false,
      child: Container(
        height: alto,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ReflejoTactil(
          radius: BorderRadius.circular(30),
          tamano: 84,
          child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // El vidrio va en su propia capa: así su recorte no corta el
            // círculo amarillo, que sobresale de la barra.
            Positioned.fill(
              child: Vidrio(
                radius: BorderRadius.circular(30),
                blur: 28,
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedAlign(
              alignment: Alignment(x, -1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              child: FractionallySizedBox(
                widthFactor: 1 / _tabItems.length,
                heightFactor: 46 / alto,
                child: Transform.translate(
                  // Saca el círculo por encima del borde de la barra.
                  offset: const Offset(0, -16),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.isDark
                            ? const Color(0xFF0E2140)
                            : Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withAlpha(110),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _tabItems.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: _tabItems[i],
                      selected: i == index,
                      onTap: () => onSelected(MiraTab.values[i]),
                    ),
                  ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSlide(
              // El icono activo salta hasta el centro del círculo.
              offset: Offset(0, selected ? -0.83 : 0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              child: AnimatedScale(
                scale: selected ? 1.05 : 1,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  selected ? item.active : item.icon,
                  size: 23,
                  color: selected ? AppColors.onAccent : palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? palette.link : palette.textSecondary,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de formulario con etiqueta encima.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.keyboardType,
    this.obscure = false,
    this.readOnly = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.helper,
    this.prefixText,
    this.inputFormatters,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool readOnly;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// Aviso en rojo bajo el campo (validación en vivo, como en la web).
  final String? errorText;

  /// Ayuda en gris bajo el campo; se oculta si hay un error.
  final String? helper;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          inputFormatters: widget.inputFormatters,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            errorMaxLines: 3,
            helperText: widget.helper,
            helperMaxLines: 2,
            prefixText: widget.prefixText,
            prefixIcon:
                widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    tooltip: _hidden ? 'Mostrar' : 'Ocultar',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Fila "etiqueta ....... valor" de las tarjetas de detalle.
class FilaDato extends StatelessWidget {
  const FilaDato({
    super.key,
    required this.label,
    required this.value,
    this.strong = true,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: strong
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dato pequeño en dos líneas (etiqueta arriba, valor abajo).
class DatoCompacto extends StatelessWidget {
  const DatoCompacto({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Barra de progreso redondeada.
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({
    super.key,
    required this.value,
    this.color = AppColors.accent,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: palette.trackBg,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

// ====================================================================
// 4. Datos de ejemplo, sesión y carrusel
// ====================================================================

/// Tipos de documento que ofrece el formulario de perfil.
const List<String> tiposDocumento = ['CC', 'CE', 'NIT', 'Pasaporte'];

/// Datos del cliente en sesión. Editables desde Perfil (en memoria).
class PerfilUsuario {
  PerfilUsuario._();

  static final PerfilUsuario instance = PerfilUsuario._();

  String nombre = 'Carlos Ramírez';
  String tipoDocumento = 'CC';
  String documento = '1023456789';
  String correo = 'carlos.ramirez@email.com';
  String telefono = '300 456 7890';
  String direccion = 'Cra. 45 #80-23, Medellín, Antioquia';

  /// "Carlos Ramírez" -> "Carlos"
  String get primerNombre =>
      nombre.split(' ').firstWhere((p) => p.isNotEmpty, orElse: () => '');

  String get iniciales {
    final partes = nombre.split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }
}

/// Cuenta recordada en el teléfono ("Recordarme" del login). Solo se
/// guarda el correo, nunca la contraseña: para volver a entrar sin
/// escribirla se usa la huella.
class SesionGuardada {
  const SesionGuardada._();

  static const String _clave = 'recordar_correo';

  /// Correo recordado, o `null` si no hay ninguno.
  static Future<String?> correo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_clave);
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordar(String correo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, correo);
    } catch (_) {
      // Sin almacenamiento disponible: simplemente no se recuerda.
    }
  }

  static Future<void> olvidar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }
}

/// Huella o rostro del teléfono Android para entrar. Usa el diálogo del
/// propio sistema, que elige el método que el usuario tenga configurado.
class Huella {
  const Huella._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// `true` si el teléfono tiene huella o rostro configurado. En la web y
  /// en las pruebas no hay biometría.
  static Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Muestra el diálogo del sistema. `true` si la huella coincide.
  static Future<bool> verificar() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a MiraLlantas',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Láminas del carrusel de Inicio.
class SlideCarrusel {
  const SlideCarrusel({
    required this.asset,
    required this.titulo,
    required this.subtitulo,
  });

  final String asset;
  final String titulo;
  final String subtitulo;
}

const List<SlideCarrusel> mockCarrusel = [
  SlideCarrusel(
    asset: 'assets/images/carrusel_llantas.png',
    titulo: 'Llantas nuevas',
    subtitulo: 'Michelin · Bridgestone · Pirelli',
  ),
  SlideCarrusel(
    asset: 'assets/images/carrusel_maquinaria.png',
    titulo: 'Maquinaria pesada',
    subtitulo: 'Minería, carga y construcción',
  ),
  SlideCarrusel(
    asset: 'assets/images/carrusel_inventario.png',
    titulo: 'Inventario disponible',
    subtitulo: 'Entrega inmediata en bodega',
  ),
];

// ====================================================================
// 5. Pantallas
// ====================================================================

/// Pantalla de carga, con el mismo diseño del splash de la web: fondo azul
/// medianoche, logo y una barra amarilla que se llena.
///
/// Se usa dos veces: al abrir la app (lleva al login) y justo después de
/// iniciar sesión, con el saludo "Preparando tu panel, Carlos...".
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.nombre,
    this.destino = AppRoutes.login,
    this.duracion = const Duration(milliseconds: 2200),
  });

  /// Primer nombre del usuario; `null` al abrir la app.
  final String? nombre;

  /// Ruta a la que se pasa cuando la barra termina de llenarse.
  final String destino;
  final Duration duracion;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duracion)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        Navigator.of(context).pushReplacementNamed(widget.destino);
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrada = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    final escala = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    final nombre = widget.nombre;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: entrada,
              child: ScaleTransition(
                scale: escala,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMira(size: 132),
                    const SizedBox(height: 22),
                    const Text(
                      'MiraLlantas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gestión de llantas y reencauche',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 224,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 4,
                  color: Colors.white.withAlpha(26),
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: Curves.easeInOut.transform(_c.value),
                      heightFactor: 1,
                      child: const ColoredBox(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nombre == null || nombre.isEmpty
                  ? 'Cargando...'
                  : 'Preparando tu panel, $nombre...',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo pequeño en tarjeta redondeada para el login.
class LogoMira extends StatelessWidget {
  const LogoMira({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // El logo ya trae su propio fondo amarillo: solo se redondea.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// Login: correo y contraseña, "Recordarme", Google y huella o rostro. Al entrar
/// se muestra la pantalla de carga con el saludo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  bool _recordar = false;

  /// Correo guardado en el teléfono (para la huella).
  String? _correoGuardado;

  /// `true` si el teléfono tiene huella o rostro configurado.
  bool _biometria = false;

  /// Los avisos aparecen después del primer intento y se corrigen en vivo.
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  /// El correo recordado se escribe en cuanto se lee; la consulta de la
  /// huella va aparte para no hacerlo esperar.
  Future<void> _cargarSesion() async {
    final correo = await SesionGuardada.correo();
    if (mounted && correo != null) {
      setState(() {
        _correoGuardado = correo;
        _correo.text = correo;
        _recordar = true;
      });
    }
    final biometria = await Huella.disponible();
    if (mounted && biometria) setState(() => _biometria = true);
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  String? get _errorCorreo => _intentado ? errorCorreo(_correo.text) : null;

  String? get _errorClave =>
      _intentado && _clave.text.isEmpty ? 'Escribe tu contraseña' : null;

  /// Pasa a la pantalla de carga y de ahí a Inicio.
  void _abrirPanel(String correo) {
    final perfil = PerfilUsuario.instance..correo = correo;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SplashScreen(
          nombre: perfil.primerNombre,
          destino: AppRoutes.home,
          duracion: const Duration(milliseconds: 1400),
        ),
      ),
    );
  }

  Future<void> _entrar() async {
    setState(() => _intentado = true);
    if (_errorCorreo != null || _errorClave != null) return;

    final correo = _correo.text.trim().toLowerCase();
    if (_recordar) {
      await SesionGuardada.recordar(correo);
    } else {
      await SesionGuardada.olvidar();
    }
    if (mounted) _abrirPanel(correo);
  }

  Future<void> _entrarConHuella() async {
    final correo = _correoGuardado;
    if (correo == null) {
      mostrarAviso(
        context,
        'Entra una vez con "Recordarme" activado para usar tu huella o '
        'tu rostro.',
      );
      return;
    }
    if (await Huella.verificar() && mounted) _abrirPanel(correo);
  }

  /// Demostración: entra con la cuenta del perfil. El inicio real con
  /// Google necesita el ID de cliente OAuth y la verificación del backend.
  void _entrarConGoogle() => _abrirPanel(PerfilUsuario.instance.correo);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LogoMira(size: 52),
                      const SizedBox(width: 12),
                      Text(
                        'MiraLlantas',
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  MiraCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text('Accede a tu cuenta',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 22),
                        CampoTexto(
                          label: 'Correo electrónico',
                          hint: 'user@mirallantas.com',
                          controller: _correo,
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          errorText: _errorCorreo,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        CampoTexto(
                          label: 'Contraseña',
                          hint: '••••••••',
                          controller: _clave,
                          prefixIcon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          errorText: _errorClave,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _entrar(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                key: const Key('login-recordar'),
                                onTap: () =>
                                    setState(() => _recordar = !_recordar),
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _recordar,
                                      onChanged: (v) =>
                                          setState(() => _recordar = v ?? false),
                                      activeColor: AppColors.accent,
                                      checkColor: AppColors.onAccent,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Flexible(
                                      child: Text(
                                        'Recordarme',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // En pantallas angostas el enlace pasa a dos líneas.
                            Flexible(
                              child: TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.recuperar),
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          key: const Key('login-entrar'),
                          onPressed: _entrar,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Iniciar sesión'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: Divider(color: palette.border)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('o continúa con',
                                  style: theme.textTheme.bodySmall),
                            ),
                            Expanded(child: Divider(color: palette.border)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('login-google'),
                                onPressed: _entrarConGoogle,
                                style: estiloBotonChico().copyWith(
                                  minimumSize: WidgetStateProperty.all(
                                    const Size(0, 50),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _LetraGoogle(),
                                    SizedBox(width: 8),
                                    Text('Google'),
                                  ],
                                ),
                              ),
                            ),
                            if (_biometria) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const Key('login-huella'),
                                  onPressed: _entrarConHuella,
                                  style: estiloBotonChico().copyWith(
                                    minimumSize: WidgetStateProperty.all(
                                      const Size(0, 50),
                                    ),
                                  ),
                                  icon: const Icon(Icons.fingerprint, size: 22),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Huella o rostro'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "G" en los colores de Google, sin imágenes ni paquetes extra.
class _LetraGoogle extends StatelessWidget {
  const _LetraGoogle();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
        stops: [0, 0.3, 0.55, 0.8, 1],
      ).createShader(rect),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Recuperar contraseña con los pasos y las reglas de la web: correo,
/// código de 6 dígitos, contraseña nueva y confirmación final.
class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  /// 0 correo · 1 código · 2 contraseña · 3 listo
  int _paso = 0;

  /// Aviso del paso actual; se limpia al corregir el dato.
  String? _error;

  final TextEditingController _correo = TextEditingController();
  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _limpiarError() {
    if (_error != null) setState(() => _error = null);
  }

  void _enviarCorreo() {
    final problema = errorCorreo(_correo.text);
    setState(() {
      _error = problema;
      if (problema == null) _paso = 1;
    });
  }

  void _verificarCodigo() {
    if (_codigo.text.length != 6) return;
    setState(() {
      _error = null;
      _paso = 2;
    });
  }

  void _guardarPassword() {
    final problema = errorPassword(_nueva.text) ??
        (_nueva.text != _confirmar.text
            ? 'Las contraseñas no coinciden.'
            : null);
    setState(() {
      _error = problema;
      if (problema == null) _paso = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const MiraHeader(title: '¿Olvidaste tu contraseña?'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                i <= _paso ? AppColors.accent : palette.trackBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                MiraCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: switch (_paso) {
                      0 => _pasoCorreo(),
                      1 => _pasoCodigo(),
                      2 => _pasoPassword(),
                      _ => _pasoListo(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _encabezado(String titulo, String texto) {
    final theme = Theme.of(context);
    return [
      Text(titulo,
          style: theme.textTheme.headlineLarge?.copyWith(fontSize: 22)),
      const SizedBox(height: 6),
      Text(texto, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _pasoCorreo() {
    return [
      ..._encabezado(
        'Ingresa tu correo',
        'Te ayudamos a recuperar el acceso a tu cuenta. Te enviaremos un '
            'código de verificación de 6 dígitos.',
      ),
      CampoTexto(
        label: 'Correo electrónico',
        hint: 'nombre@correo.com',
        controller: _correo,
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        errorText: _error,
        onChanged: (_) => _limpiarError(),
        onSubmitted: (_) => _enviarCorreo(),
      ),
      const SizedBox(height: 22),
      ElevatedButton(
        onPressed: _enviarCorreo,
        child: const Text('Enviar código'),
      ),
    ];
  }

  List<Widget> _pasoCodigo() {
    final theme = Theme.of(context);
    return [
      ..._encabezado(
        'Código de verificación',
        'Revisa ${_correo.text.trim()} e ingresa el código de 6 dígitos.',
      ),
      TextField(
        key: const Key('recuperar-codigo'),
        controller: _codigo,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _verificarCodigo(),
        style: theme.textTheme.headlineLarge?.copyWith(
          fontSize: 28,
          letterSpacing: 10,
          color: context.palette.link,
        ),
        decoration: const InputDecoration(
          counterText: '',
          hintText: '······',
        ),
      ),
      const SizedBox(height: 22),
      ElevatedButton(
        onPressed: _codigo.text.length == 6 ? _verificarCodigo : null,
        child: const Text('Verificar código'),
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: () =>
              mostrarAviso(context, 'Te enviamos un código nuevo.'),
          child: const Text('¿No recibiste el código? Reenviar'),
        ),
      ),
    ];
  }

  List<Widget> _pasoPassword() {
    return [
      ..._encabezado(
        'Nueva contraseña',
        'Elige una contraseña segura para tu cuenta.',
      ),
      CampoTexto(
        label: 'Nueva contraseña',
        hint: '••••••••••',
        controller: _nueva,
        obscure: true,
        helper: ayudaPassword,
        onChanged: (_) => _limpiarError(),
      ),
      const SizedBox(height: 16),
      CampoTexto(
        label: 'Repite la contraseña',
        hint: '••••••••••',
        controller: _confirmar,
        obscure: true,
        errorText: _error,
        onChanged: (_) => _limpiarError(),
        onSubmitted: (_) => _guardarPassword(),
      ),
      const SizedBox(height: 22),
      ElevatedButton(
        onPressed: _guardarPassword,
        child: const Text('Guardar contraseña'),
      ),
    ];
  }

  List<Widget> _pasoListo() {
    final theme = Theme.of(context);
    final palette = context.palette;
    return [
      const SizedBox(height: 6),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: palette.successSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: palette.successFg, size: 32),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Contraseña actualizada',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        'Ya puedes iniciar sesión con tu nueva contraseña.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 22),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver a iniciar sesión'),
      ),
    ];
  }
}

/// Pestaña visible del contenedor principal. Vive fuera del widget para
/// que cualquier pantalla pueda saltar a otra sección (por ejemplo, el
/// "Ver todas" de Inicio abre Cotizaciones).
class ShellController extends ValueNotifier<MiraTab> {
  ShellController._() : super(MiraTab.inicio);

  static final ShellController instance = ShellController._();

  void ir(MiraTab tab) => value = tab;

  /// Estado de entrega con el que se abre Cotizaciones (por ejemplo, desde
  /// "Próxima entrega" de Inicio). `null` = todas.
  final ValueNotifier<String?> filtroEntrega = ValueNotifier<String?>(null);

  void verEntregas(String? estado) {
    filtroEntrega.value = estado;
    ir(MiraTab.cotizaciones);
  }
}

/// Contenedor principal: cuatro pestañas, cada una con su propio
/// Navigator para que la barra inferior no se pierda al entrar a un
/// detalle.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ShellController _controller = ShellController.instance;

  final Map<MiraTab, GlobalKey<NavigatorState>> _keys = {
    for (final t in MiraTab.values) t: GlobalKey<NavigatorState>(),
  };

  MiraTab get _tab => _controller.value;

  @override
  void initState() {
    super.initState();
    // Cada sesión arranca en Inicio.
    _controller.value = MiraTab.inicio;
    _controller.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _controller.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  void _select(MiraTab tab) {
    if (tab == _tab) {
      // Volver a tocar la pestaña activa regresa a su pantalla raíz.
      _keys[tab]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _controller.ir(tab);
  }

  Widget _raiz(MiraTab tab) => switch (tab) {
        MiraTab.inicio => const InicioScreen(),
        MiraTab.cotizaciones => const CotizacionesScreen(),
        MiraTab.cartera => const CarteraScreen(),
        MiraTab.perfil => const PerfilScreen(),
      };

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.transparent,
      // El contenido se desplaza por debajo de la barra de vidrio.
      extendBody: true,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _keys[_tab]!.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else if (_tab != MiraTab.inicio) {
            _controller.ir(MiraTab.inicio);
          }
        },
        child: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in MiraTab.values)
              Navigator(
                key: _keys[tab],
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  builder: (_) => _raiz(tab),
                  settings: settings,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: MiraNavBar(current: _tab, onSelected: _select),
    );
  }
}

/// Inicio del portal: los mismos indicadores de la web y las cotizaciones
/// recientes; debajo, el carrusel de fotos propio de la app.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartera = CarteraStore.instance;
    final cotizaciones = CotizacionesStore.instance;
    final perfil = PerfilUsuario.instance;

    return Column(
      children: [
        MiraHeader(
          title: 'Hola, ${perfil.primerNombre}',
          subtitle: 'Portal de cliente · MiraLlantas',
          showBack: false,
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([cartera, cotizaciones]),
            builder: (context, _) {
              final pendientes = cotizaciones.pendientes;
              Cotizacion? enCamino;
              for (final c in cotizaciones.cotizaciones) {
                if (c.estadoEntrega == 'En camino') {
                  enCamino = c;
                  break;
                }
              }
              final saldo = cartera.saldoPendiente;
              final tieneCredito = cartera.tieneCredito;

              return ListView(
                padding: margenPagina(context),
                children: [
                  _FilaStats(
                    izquierda: StatCard(
                      label: 'MIS PEDIDOS-COTIZACIÓN',
                      value: '${cotizaciones.cotizaciones.length}',
                      sub: pendientes == 1
                          ? '1 cotización pendiente'
                          : '$pendientes cotizaciones pendientes',
                      icon: Icons.description_outlined,
                      tono: EstadoTono.aviso,
                      onTap: () =>
                          ShellController.instance.ir(MiraTab.cotizaciones),
                    ),
                    derecha: StatCard(
                      label: 'PRÓXIMA ENTREGA',
                      value: enCamino?.id ?? '—',
                      sub: enCamino != null
                          ? 'En camino'
                          : 'Ninguna entrega en camino',
                      icon: Icons.local_shipping_outlined,
                      tono: EstadoTono.info,
                      onTap: () => ShellController.instance
                          .verEntregas(enCamino != null ? 'En camino' : null),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FilaStats(
                    izquierda: StatCard(
                      label: 'MI CRÉDITO',
                      value: formatCop(saldo),
                      sub: saldo > 0
                          ? 'Saldo pendiente de tu crédito'
                          : 'Sin créditos abiertos',
                      icon: Icons.credit_card,
                      tono: EstadoTono.exito,
                      onTap: () =>
                          ShellController.instance.ir(MiraTab.cartera),
                    ),
                    derecha: StatCard(
                      label: 'TOTAL COMPRADO',
                      value: formatCop(cotizaciones.totalComprado),
                      sub: 'Este año',
                      icon: Icons.attach_money,
                      tono: EstadoTono.violeta,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatCard(
                    label: 'ESTADO DEL CRÉDITO',
                    value:
                        tieneCredito ? formatCop(saldo) : 'Sin crédito abierto',
                    sub: tieneCredito
                        ? 'Saldo pendiente de tu crédito'
                        : 'Puedes solicitar un crédito',
                    icon: Icons.account_balance_wallet_outlined,
                    tono: tieneCredito ? EstadoTono.error : EstadoTono.exito,
                    onTap: () => ShellController.instance.ir(MiraTab.cartera),
                  ),
                  const SizedBox(height: 14),
                  _CotizacionesRecientes(lista: cotizaciones.ordenadas),
                  const SizedBox(height: 22),
                  const CarruselInicio(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Dos indicadores lado a lado, del mismo alto.
class _FilaStats extends StatelessWidget {
  const _FilaStats({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: izquierda),
          const SizedBox(width: 12),
          Expanded(child: derecha),
        ],
      ),
    );
  }
}

/// "Mis Pedidos-Cotización Recientes": las cuatro primeras y el enlace
/// a la lista completa.
class _CotizacionesRecientes extends StatelessWidget {
  const _CotizacionesRecientes({required this.lista});

  final List<Cotizacion> lista;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final visibles = lista.take(4).toList();

    return MiraCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mis Pedidos-Cotización Recientes',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ShellController.instance.ir(MiraTab.cotizaciones),
                child: const Text('Ver todas'),
              ),
            ],
          ),
          for (var i = 0; i < visibles.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visibles[i].id,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontSize: 14),
                        ),
                        Text(visibles[i].fecha,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    visibles[i].totalTexto,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  EstadoChip.de(visibles[i].estado),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Center(
              child: Text(
                'Mostrando ${visibles.length} de ${lista.length}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrusel de fotos con avance automático y puntos indicadores.
class CarruselInicio extends StatefulWidget {
  const CarruselInicio({super.key});

  @override
  State<CarruselInicio> createState() => _CarruselInicioState();
}

class _CarruselInicioState extends State<CarruselInicio> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _irA(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: mockCarrusel.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final slide = mockCarrusel[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(slide.asset, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xE60D1520), Color(0x330D1520)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.titulo,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 21,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slide.subtitulo,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < mockCarrusel.length; i++)
              GestureDetector(
                onTap: () => _irA(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.accent : palette.trackBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Botón compacto para las acciones dentro de las tarjetas.
ButtonStyle estiloBotonChico() {
  return ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(0, 42)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 12),
    ),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

/// Color del contorno de una tarjeta según cómo va su crédito.
Color? bordeDeCondicion(MiraPalette palette, String? condicion) {
  return switch (condicion) {
    'Al día' => palette.successFg,
    'Vencido' => palette.dangerFg,
    creditoSinIniciar => AppColors.accent,
    _ => null,
  };
}

const String _avisoPdf =
    'El PDF se podrá descargar cuando la app esté conectada al servidor.';

/// Pide el método de pago y acepta la cotización formal.
Future<void> aceptarCotizacion(BuildContext context, Cotizacion c) async {
  final metodo = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DialogoAceptar(cotizacion: c),
  );
  if (metodo == null) return;
  CotizacionesStore.instance.aceptar(c, metodo);
  if (!context.mounted) return;
  mostrarAviso(
    context,
    'Cotización ${c.id} aceptada. El pago queda pendiente de validación.',
  );
}

/// Pide el motivo y cancela una cotización que aún no se ha aceptado.
Future<void> cancelarCotizacion(BuildContext context, Cotizacion c) async {
  final motivo = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DialogoMotivo(cotizacion: c),
  );
  if (motivo == null) return;
  CotizacionesStore.instance.cancelar(c, motivo);
  if (!context.mounted) return;
  mostrarAviso(context, 'Cotización ${c.id} cancelada.');
}

/// Diálogo sobre vidrio: desenfoca la pantalla que queda detrás y usa una
/// superficie casi sólida, para que el texto se lea sin competir con el fondo.
class _DialogoVidrio extends StatelessWidget {
  const _DialogoVidrio({
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final solido = MediaQuery.highContrastOf(context);
    final dialogo = AlertDialog(
      backgroundColor:
          solido ? palette.surface : palette.surface.withAlpha(235),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: Vidrio.filo(palette)),
      ),
      title: title,
      content: content,
      actions: actions,
    );
    if (solido) return dialogo;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: dialogo,
    );
  }
}

class _DialogoAceptar extends StatelessWidget {
  const _DialogoAceptar({required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tieneCredito = CarteraStore.instance.tieneCredito;
    final inicial = (cotizacion.total * 0.3).round();

    return _DialogoVidrio(
      title: Text('Aceptar cotización', style: theme.textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${cotizacion.id} · Total ${formatCop(cotizacion.total)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text('¿Cómo quieres pagarla?', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('Contado'),
            style: estiloBotonChico(),
            child: const Text('Contado'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed:
                tieneCredito ? null : () => Navigator.of(context).pop('Crédito'),
            style: estiloBotonChico(),
            child: Text('Crédito · inicial de ${formatCop(inicial)} (30 %)'),
          ),
          if (tieneCredito) ...[
            const SizedBox(height: 8),
            Text(
              'Solo puedes tener un crédito a la vez: paga el que tienes '
              'abierto para solicitar otro.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
      ],
    );
  }
}

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final TextEditingController _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final listo = _motivo.text.trim().isNotEmpty;

    return _DialogoVidrio(
      title: Text('Cancelar la cotización', style: theme.textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.cotizacion.id} · ${widget.cotizacion.totalTexto}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Queda cancelada y le avisamos al asesor. Esta acción no se '
            'puede deshacer.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          CampoTexto(
            label: '¿Por qué la cancelas?',
            hint: 'Escribe el motivo',
            controller: _motivo,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        TextButton(
          onPressed:
              listo ? () => Navigator.of(context).pop(_motivo.text.trim()) : null,
          style: TextButton.styleFrom(foregroundColor: palette.dangerFg),
          child: const Text('Cancelar cotización'),
        ),
      ],
    );
  }
}

/// "Mis Cotizaciones-Pedido": buscador, filtro por etapa y una tarjeta por
/// cotización con sus cinco estados, igual que en el portal web.
class CotizacionesScreen extends StatefulWidget {
  const CotizacionesScreen({super.key});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  static const List<String> _etapas = [
    'Solicitud',
    'Emitida',
    'Vencida',
    'Aceptada',
  ];

  /// Las entregas ya no tienen pestaña propia: se siguen por el estado
  /// de entrega de cada cotización.
  static const List<String> _entregas = [
    'Pendiente',
    'En camino',
    'Entregado',
    'Cancelado',
  ];

  final TextEditingController _buscar = TextEditingController();

  /// `null` = todas las etapas.
  String? _etapa;

  /// Filtro por estado de entrega; lo comparte Inicio ("Próxima entrega").
  final ValueNotifier<String?> _entrega =
      ShellController.instance.filtroEntrega;

  @override
  void initState() {
    super.initState();
    _entrega.addListener(_refrescar);
  }

  @override
  void dispose() {
    _entrega.removeListener(_refrescar);
    _buscar.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  bool _coincide(Cotizacion c) {
    if (_etapa != null && c.etapa != _etapa) return false;
    final entrega = _entrega.value;
    if (entrega != null && c.estadoEntrega != entrega) return false;
    final texto = _buscar.text.trim().toLowerCase();
    if (texto.isEmpty) return true;
    final credito = CarteraStore.instance.deCotizacion(c.id);
    final buscable =
        '${c.id} ${c.fecha} ${c.totalTexto} ${credito?.id ?? ''}'.toLowerCase();
    return buscable.contains(texto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final store = CotizacionesStore.instance;

    return Column(
      children: [
        const MiraHeader(title: 'Mis Cotizaciones', showBack: false),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([store, CarteraStore.instance]),
            builder: (context, _) {
              final visibles = store.ordenadas.where(_coincide).toList();
              return ListView(
                padding: margenPagina(context),
                children: [
                  Text(
                    'Historial completo de tus solicitudes · las de crédito '
                    'aparecen primero',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _buscar,
                    onChanged: (_) => setState(() {}),
                    style: theme.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por número, fecha o crédito',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FilaFiltros(
                    titulo: 'ETAPA',
                    opciones: _etapas,
                    actual: _etapa,
                    onCambio: (e) => setState(() => _etapa = e),
                  ),
                  const SizedBox(height: 10),
                  _FilaFiltros(
                    titulo: 'ENTREGA',
                    opciones: _entregas,
                    actual: _entrega.value,
                    onCambio: (e) => _entrega.value = e,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    visibles.length == 1
                        ? '1 COTIZACIÓN'
                        : '${visibles.length} COTIZACIONES',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 12),
                  if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 34, color: palette.textMuted),
                          const SizedBox(height: 10),
                          Text('Sin cotizaciones',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Ninguna cotización coincide con la búsqueda.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  for (final cot in visibles) ...[
                    _CotizacionCard(cotizacion: cot),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Título pequeño y una fila desplazable de filtros ("Todas" + opciones).
class _FilaFiltros extends StatelessWidget {
  const _FilaFiltros({
    required this.titulo,
    required this.opciones,
    required this.actual,
    required this.onCambio,
  });

  final String titulo;
  final List<String> opciones;
  final String? actual;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ChipFiltro(
                label: 'Todas',
                selected: actual == null,
                onTap: () => onCambio(null),
              ),
              for (final o in opciones) ...[
                const SizedBox(width: 8),
                _ChipFiltro(
                  label: o,
                  selected: actual == o,
                  onTap: () => onCambio(o),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.accentSoft : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.link : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Fila "ETAPA  [pastilla]" de la tarjeta de cotización.
class _FilaEstado extends StatelessWidget {
  const _FilaEstado({required this.label, this.estado, this.texto});

  final String label;

  /// Estado que da el color; `null` = no aplica (se muestra un guion).
  final String? estado;

  /// Texto visible si es distinto del estado.
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valor = estado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontSize: 10, letterSpacing: 0.6),
            ),
          ),
          if (valor == null)
            Text('—', style: theme.textTheme.bodySmall)
          else
            Flexible(child: EstadoChip.de(texto ?? valor, estado: valor)),
        ],
      ),
    );
  }
}

/// Renglón con icono pequeño y texto gris.
class _LineaIcono extends StatelessWidget {
  const _LineaIcono({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: palette.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  const _CotizacionCard({required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final c = cotizacion;
    final credito = CarteraStore.instance.deCotizacion(c.id);
    // Pago rechazado: la tarjeta se marca en rojo hasta que se vuelva a pagar.
    final borde = c.estadoPago == 'Rechazado'
        ? palette.dangerFg
        : bordeDeCondicion(palette, credito?.condicion);

    void abrir() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CotizacionDetalleScreen(cotizacion: c),
        ),
      );
    }

    return MiraCard(
      borderColor: borde,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilaEstado(label: 'ETAPA', estado: c.etapa, texto: c.etapaTexto),
          _FilaEstado(label: 'CRÉDITO', estado: credito?.condicion),
          _FilaEstado(label: 'PAGO', estado: c.estadoPago),
          _FilaEstado(label: 'COTIZACIÓN', estado: c.estado),
          _FilaEstado(label: 'ENTREGA', estado: c.estadoEntrega),
          const SizedBox(height: 12),
          Text(c.id, style: theme.textTheme.titleMedium),
          _LineaIcono(icon: Icons.calendar_today_outlined, texto: c.fecha),
          const SizedBox(height: 6),
          _LineaIcono(
            icon: Icons.inventory_2_outlined,
            texto: c.llantas == 1 ? '1 llanta' : '${c.llantas} llantas',
          ),
          _LineaIcono(
            icon: Icons.credit_card,
            texto: c.metodoPago ?? 'Se elige al aceptar la cotización',
          ),
          _LineaIcono(icon: Icons.place_outlined, texto: c.direccion),
          Divider(height: 26, color: palette.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('TOTAL', style: theme.textTheme.labelSmall),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    c.totalTexto,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                  ),
                  if (c.conServicios && c.etapa != 'Solicitud')
                    Text(
                      'Incluye servicios por ${formatCop(c.totalServicios)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VigenciaYAcciones(cotizacion: c),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: abrir,
              style: estiloBotonChico(),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('Ver detalle completo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caja gris de la tarjeta: la vigencia y lo que el cliente puede hacer
/// según la etapa de la cotización.
class _VigenciaYAcciones extends StatelessWidget {
  const _VigenciaYAcciones({required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final c = cotizacion;

    Widget nota(IconData icon, String texto, Color color) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.estado == 'Rechazada')
            nota(
              Icons.block,
              'Cotización cancelada'
              '${c.motivoCancelacion == null ? '' : ' · ${c.motivoCancelacion}'}',
              palette.dangerFg,
            )
          else if (c.etapa == 'Solicitud')
            nota(
              Icons.hourglass_empty,
              'Estamos confirmando los precios con nuestros proveedores '
              '(respuesta en hasta $plazoRespuestaHoras horas). Todavía no '
              'es una cotización formal.',
              palette.warningFg,
            )
          else if (c.etapa == 'Emitida') ...[
            nota(
              Icons.event_outlined,
              'Válida hasta el ${c.venceEn ?? '—'} '
              '($vigenciaCotizacionDias días)',
              palette.textSecondary,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => aceptarCotizacion(context, c),
                    style: estiloBotonChico(),
                    icon: const Icon(Icons.handshake_outlined, size: 17),
                    label: const Text('Aceptar cotización'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => mostrarAviso(context, _avisoPdf),
                  style: estiloBotonChico(),
                  icon: const Icon(Icons.file_download_outlined, size: 17),
                  label: const Text('PDF'),
                ),
              ],
            ),
          ] else if (c.etapa == 'Vencida')
            nota(
              Icons.event_busy_outlined,
              'Venció el ${c.venceEn ?? '—'}. Escríbenos para actualizar '
              'los precios.',
              palette.dangerFg,
            )
          else
            InkWell(
              onTap: () => mostrarAviso(context, _avisoPdf),
              child: nota(
                Icons.file_download_outlined,
                'Descargar la cotización (PDF)',
                palette.textSecondary,
              ),
            ),
          if (c.cancelable) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => cancelarCotizacion(context, c),
              child: nota(Icons.block, 'Cancelar cotización', palette.dangerFg),
            ),
          ],
        ],
      ),
    );
  }
}

/// Detalle completo de una cotización: fechas, productos y servicios,
/// pago, seguimiento de la entrega y su crédito.
class CotizacionDetalleScreen extends StatelessWidget {
  const CotizacionDetalleScreen({super.key, required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final c = cotizacion;

    return Column(
      children: [
        MiraHeader(title: 'Cotización ${c.id}'),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge(
              [CotizacionesStore.instance, CarteraStore.instance],
            ),
            builder: (context, _) {
              final credito = CarteraStore.instance.deCotizacion(c.id);
              final vigencia = c.etapa == 'Solicitud'
                  ? 'Empieza al emitirla'
                  : c.emitidaEn != null
                      ? '$vigenciaCotizacionDias días calendario'
                      : 'No aplica';

              return ListView(
                padding: margenPagina(context),
                children: [
                  MiraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            EstadoChip.de(c.estado),
                            EstadoChip.de(c.etapaTexto, estado: c.etapa),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RejillaDatos(
                          datos: [
                            ('SOLICITADA', c.fecha),
                            ('EMITIDA', c.emitidaEn ?? 'Pendiente'),
                            ('VENCE', c.venceEn ?? '—'),
                            ('VIGENCIA', vigencia),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('PRODUCTOS Y SERVICIOS',
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  MiraCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < c.lineas.length; i++) ...[
                          if (i > 0) Divider(height: 22, color: palette.border),
                          _LineaProducto(linea: c.lineas[i]),
                        ],
                        Divider(height: 24, color: palette.border),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Total',
                                  style: theme.textTheme.titleMedium),
                            ),
                            Text(
                              c.totalTexto,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontSize: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('PAGO', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  MiraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilaDato(
                          label: 'Método de pago',
                          value: c.metodoPago ??
                              'Se elige al aceptar la cotización',
                          strong: false,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Estado del pago',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            if (c.estadoPago == null)
                              Text('—', style: theme.textTheme.bodyMedium)
                            else
                              EstadoChip.de(c.estadoPago!),
                          ],
                        ),
                        if (c.etapa == 'Emitida' &&
                            c.estado == 'Pendiente') ...[
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => aceptarCotizacion(context, c),
                            style: estiloBotonChico(),
                            icon:
                                const Icon(Icons.handshake_outlined, size: 17),
                            label: const Text('Aceptar cotización'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('ENTREGA', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (c.estadoEntrega == 'Cancelado')
                    AvisoCaja(
                      tono: EstadoTono.error,
                      icon: Icons.block,
                      texto: 'Entrega cancelada'
                          '${c.motivoCancelacion == null ? '' : ' · ${c.motivoCancelacion}'}',
                    )
                  else
                    MiraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PasosEntrega(estado: c.estadoEntrega),
                          const SizedBox(height: 6),
                          _LineaIcono(
                            icon: Icons.place_outlined,
                            texto: c.direccion,
                          ),
                        ],
                      ),
                    ),
                  if (credito != null) ...[
                    const SizedBox(height: 22),
                    Text('CRÉDITO ${credito.id}',
                        style: theme.textTheme.labelSmall),
                    const SizedBox(height: 12),
                    _ResumenCredito(credito: credito),
                  ],
                  if (c.estado == 'Completada') ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => mostrarAviso(
                        context,
                        'El recibo se podrá ver cuando la app esté '
                        'conectada al servidor.',
                      ),
                      style: estiloBotonChico(),
                      icon: const Icon(Icons.receipt_long_outlined, size: 17),
                      label: const Text('Ver recibo'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineaProducto extends StatelessWidget {
  const _LineaProducto({required this.linea});

  final LineaCotizacion linea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final (Color fg, Color bg) = coloresDeTono(
      palette,
      linea.esServicio ? EstadoTono.info : EstadoTono.aviso,
    );
    final unitario = linea.valorUnitario;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            linea.esServicio
                ? Icons.build_outlined
                : Icons.inventory_2_outlined,
            size: 16,
            color: fg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                linea.nombre,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                unitario == null
                    ? '${linea.medida} · ${linea.cantidad} unidades'
                    : '${linea.medida} · ${linea.cantidad} × '
                        '${formatCop(unitario)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unitario == null ? 'Por confirmar' : formatCop(linea.subtotal),
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

void _abrirRegistrarAbono(
  BuildContext context,
  Credito credito, {
  Abono? reintento,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          RegistrarAbonoScreen(credito: credito, reintento: reintento),
    ),
  );
}

void _abrirDetalleAbono(BuildContext context, Abono abono) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DetalleAbonoScreen(abono: abono)),
  );
}

/// Renglón de un abono: número, monto, fecha, medio y estado.
class _FilaAbono extends StatelessWidget {
  const _FilaAbono({required this.abono});

  final Abono abono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return InkWell(
      onTap: () => _abrirDetalleAbono(context, abono),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(Icons.receipt_outlined, size: 16, color: palette.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${abono.id} · ${formatCop(abono.monto)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                  ),
                  Text(
                    '${abono.fecha} · ${abono.metodo}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EstadoChip.de(abono.estado),
          ],
        ),
      ),
    );
  }
}

/// Lista de abonos de un crédito. El abono rechazado que aún no se ha
/// reemplazado trae el motivo y el botón para volver a subirlo.
class _ListaAbonos extends StatelessWidget {
  const _ListaAbonos({required this.credito, this.maximo});

  final Credito credito;

  /// Cuántos mostrar; `null` = todos.
  final int? maximo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final limite = maximo;
    final abonos = limite == null
        ? credito.abonos
        : credito.abonos.take(limite).toList();
    if (abonos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < abonos.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.border),
            if (credito.pideReintento(abonos[i]))
              Container(
                color: palette.dangerSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilaAbono(abono: abonos[i]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Abono rechazado: '
                            '${abonos[i].motivoRechazo ?? 'el comprobante no se pudo validar.'} '
                            'Vuelve a subirlo.',
                            style: TextStyle(
                              color: palette.dangerFg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _abrirRegistrarAbono(
                              context,
                              credito,
                              reintento: abonos[i],
                            ),
                            style: estiloBotonChico().copyWith(
                              backgroundColor: WidgetStateProperty.all(
                                AppColors.danger,
                              ),
                              foregroundColor:
                                  WidgetStateProperty.all(Colors.white),
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Volver a subir el abono'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              _FilaAbono(abono: abonos[i]),
          ],
        ],
      ),
    );
  }
}

/// Botón "Registrar abono" con sus tres variantes: disponible, crédito
/// pagado o crédito que aún no empieza.
class _BotonAbono extends StatelessWidget {
  const _BotonAbono({required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    if (!credito.recibeAbonos) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          credito.iniciado
              ? 'Crédito pagado: no recibe más abonos'
              : 'Paga la cuota inicial desde "Mis cotizaciones" para empezar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _abrirRegistrarAbono(context, credito),
        style: estiloBotonChico().copyWith(
          foregroundColor: WidgetStateProperty.all(context.palette.link),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.accent),
          ),
        ),
        icon: const Icon(Icons.add, size: 17),
        label: const Text('Registrar abono'),
      ),
    );
  }
}

/// Bloque de un crédito: estado, las cuatro cifras, sus abonos y el botón
/// de abonar. Lo comparten la cartera y el detalle de la cotización.
class _ResumenCredito extends StatelessWidget {
  const _ResumenCredito({required this.credito, this.onTap});

  final Credito credito;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final condicion = credito.condicion;

    return MiraCard(
      borderColor: bordeDeCondicion(palette, condicion) ?? palette.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.credit_card, size: 19, color: palette.link),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(credito.id, style: theme.textTheme.titleMedium),
                    Text(
                      credito.iniciado
                          ? '${credito.cotizacion} · vence el '
                              '${credito.fechaLimite}'
                          : '${credito.cotizacion} · empieza al pagar la '
                              'cuota inicial',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EstadoChip.de(condicion),
          const SizedBox(height: 12),
          RejillaDatos(
            datos: [
              ('MONTO', formatCop(credito.montoTotal)),
              ('SALDO', formatCop(credito.saldo)),
              ('PLAZO', '${credito.plazoDias} días'),
              (
                'APERTURA',
                credito.iniciado ? credito.fechaApertura : 'Al pagar la cuota',
              ),
            ],
          ),
          const SizedBox(height: 12),
          BarraProgreso(
            value: credito.progreso,
            height: 7,
            color: condicion == 'Vencido' ? AppColors.danger : AppColors.accent,
          ),
          const SizedBox(height: 6),
          Text('${credito.porcentaje}% pagado',
              style: theme.textTheme.bodySmall),
          if (credito.abonos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ListaAbonos(credito: credito, maximo: 3),
          ],
          const SizedBox(height: 12),
          _BotonAbono(credito: credito),
        ],
      ),
    );
  }
}

/// "Mi cartera": estado del crédito, créditos con sus abonos y
/// solicitudes de crédito.
class CarteraScreen extends StatelessWidget {
  const CarteraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final store = CarteraStore.instance;

    return Column(
      children: [
        const MiraHeader(title: 'Mi cartera', showBack: false),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final tieneCredito = store.tieneCredito;
              final solicitudes = store.solicitudes;
              return ListView(
                padding: margenPagina(context),
                children: [
                  Text('Créditos, abonos y solicitudes',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  StatCard(
                    label: 'ESTADO DEL CRÉDITO',
                    value:
                        tieneCredito ? 'Crédito abierto' : 'Sin crédito abierto',
                    sub: tieneCredito
                        ? 'Págalo para poder solicitar otro'
                        : 'Puedes solicitar un crédito',
                    icon: Icons.account_balance_wallet_outlined,
                    tono: tieneCredito ? EstadoTono.error : EstadoTono.exito,
                  ),
                  const SizedBox(height: 12),
                  _FilaStats(
                    izquierda: StatCard(
                      label: 'SALDO PENDIENTE',
                      value: formatCop(store.saldoPendiente),
                      sub: 'Comprometido en créditos',
                      icon: Icons.credit_card,
                      tono: EstadoTono.aviso,
                    ),
                    derecha: StatCard(
                      label: 'CRÉDITOS',
                      value: '${store.creditos.length}',
                      sub: solicitudes.length == 1
                          ? '1 solicitud'
                          : '${solicitudes.length} solicitudes',
                      icon: Icons.description_outlined,
                      tono: EstadoTono.info,
                    ),
                  ),
                  if (tieneCredito) ...[
                    const SizedBox(height: 14),
                    const AvisoCaja(
                      tono: EstadoTono.error,
                      texto: 'Solo puedes tener un crédito a la vez. '
                          'Mientras esté abierto no puedes solicitar otro.',
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('MIS CRÉDITOS', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (store.creditos.isEmpty)
                    const _Vacio(
                      texto: 'Todavía no tienes créditos: todas tus compras '
                          'han sido de contado.',
                    ),
                  for (final credito in store.creditos) ...[
                    _ResumenCredito(
                      credito: credito,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CarteraDetalleScreen(credito: credito),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                  Text('MIS SOLICITUDES DE CRÉDITO',
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (solicitudes.isEmpty)
                    const _Vacio(
                      texto: 'Todavía no has solicitado ningún crédito.',
                    )
                  else
                    MiraCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (var i = 0; i < solicitudes.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: palette.border),
                            _FilaSolicitud(solicitud: solicitudes[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Recuadro punteado de "todavía no hay nada".
class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _FilaSolicitud extends StatelessWidget {
  const _FilaSolicitud({required this.solicitud});

  final SolicitudCredito solicitud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final s = solicitud;
    final detalle = [
      if (s.cotizacion != null) 'Pedido ${s.cotizacion}',
      s.fecha,
      '${s.plazoDias} días',
      if (s.estado == 'Pendiente') 'en revisión',
      if (s.motivo != null) s.motivo!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 17, color: palette.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.id} · ${formatCop(s.monto)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                Text(detalle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EstadoChip.de(s.estado),
        ],
      ),
    );
  }
}

/// Detalle de un crédito: saldo, cifras, accesos a abono e historial.
class CarteraDetalleScreen extends StatelessWidget {
  const CarteraDetalleScreen({super.key, required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = CarteraStore.instance;

    return Column(
      children: [
        MiraHeader(title: credito.id),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final condicion = credito.condicion;
              return ListView(
                padding: margenPagina(context),
                children: [
                  MiraCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Saldo pendiente',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            EstadoChip.de(condicion),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(formatCop(credito.saldo),
                            style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 14),
                        BarraProgreso(
                          value: credito.progreso,
                          color: condicion == 'Vencido'
                              ? AppColors.danger
                              : AppColors.accent,
                        ),
                        const SizedBox(height: 6),
                        Text('${credito.porcentaje}% pagado',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 14),
                        RejillaDatos(
                          datos: [
                            ('MONTO', formatCop(credito.montoTotal)),
                            ('ABONADO', formatCop(credito.abonado)),
                            ('PLAZO', '${credito.plazoDias} días'),
                            ('COTIZACIÓN', credito.cotizacion),
                            (
                              'APERTURA',
                              credito.iniciado
                                  ? credito.fechaApertura
                                  : 'Al pagar la cuota',
                            ),
                            (
                              'VENCE',
                              credito.iniciado
                                  ? credito.fechaLimite
                                  : 'Al pagar la cuota',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BotonAbono(credito: credito),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HistorialAbonosScreen(credito: credito),
                        ),
                      ),
                      style: estiloBotonChico(),
                      icon: const Icon(Icons.history, size: 17),
                      label: const Text('Ver historial'),
                    ),
                  ),
                  if (credito.abonos.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('ÚLTIMOS ABONOS', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 12),
                    _ListaAbonos(credito: credito, maximo: 3),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Registro de un abono con las reglas de la web: mínimo de $ 20.000 (o el
/// saldo exacto), efectivo o transferencia, y pantallazo obligatorio si es
/// transferencia. El abono queda pendiente hasta que un asesor lo valide.
class RegistrarAbonoScreen extends StatefulWidget {
  const RegistrarAbonoScreen({
    super.key,
    required this.credito,
    this.reintento,
  });

  final Credito credito;

  /// Abono rechazado que se vuelve a subir: arranca con su monto y su medio.
  final Abono? reintento;

  @override
  State<RegistrarAbonoScreen> createState() => _RegistrarAbonoScreenState();
}

class _RegistrarAbonoScreenState extends State<RegistrarAbonoScreen> {
  final TextEditingController _monto = TextEditingController();
  String? _metodo;
  bool _comprobante = false;

  /// Los avisos de campos vacíos aparecen después del primer intento.
  bool _intentado = false;

  Credito get _credito => widget.credito;

  /// Si queda menos del abono mínimo, el último pago es por el saldo
  /// completo: el monto se fija y no se puede cambiar.
  bool get _pagoTotalObligatorio =>
      _credito.saldo > 0 && _credito.saldo < abonoMinimo;

  @override
  void initState() {
    super.initState();
    final reintento = widget.reintento;
    if (_pagoTotalObligatorio) {
      _monto.text = formatCop(_credito.saldo).substring(2);
    } else if (reintento != null) {
      _monto.text = formatCop(reintento.monto).substring(2);
    }
    _metodo = reintento?.metodo;
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  int get _valor => parseCop(_monto.text);

  bool get _requiereSoporte => _metodo == 'Transferencia';

  String? get _errorMonto {
    if (_valor == 0 && !_intentado) return null;
    return CarteraStore.instance.errorMonto(_credito, _valor);
  }

  String? get _errorMetodo =>
      _intentado && _metodo == null ? 'Este campo es obligatorio' : null;

  String? get _errorSoporte => _intentado && _requiereSoporte && !_comprobante
      ? 'Adjunta el pantallazo de la consignación'
      : null;

  void _guardar() {
    setState(() => _intentado = true);
    final metodo = _metodo;
    if (_errorMonto != null || metodo == null || _errorSoporte != null) return;

    final abono = CarteraStore.instance.registrarAbono(
      credito: _credito,
      monto: _valor,
      metodo: metodo,
      conComprobante: _requiereSoporte && _comprobante,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AbonoConfirmadoScreen(abono: abono),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final errorMonto = _errorMonto;
    final errorMetodo = _errorMetodo;
    final errorSoporte = _errorSoporte;

    String? ayudaMonto;
    if (_pagoTotalObligatorio) {
      ayudaMonto = 'El saldo es menor a ${formatCop(abonoMinimo)}: este '
          'último abono debe pagar el total pendiente.';
    } else if (_valor > 0) {
      final queda = (_credito.saldo - _valor).clamp(0, _credito.saldo);
      ayudaMonto = 'Quedaría ${formatCop(queda)}';
    }

    return Column(
      children: [
        const MiraHeader(title: 'Registrar abono'),
        Expanded(
          child: ListView(
            padding: margenPagina(context, top: 18),
            children: [
              Text('Se aplicará al crédito ${_credito.id}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_credito.id,
                                  style: theme.textTheme.titleMedium),
                              Text(
                                '${_credito.cotizacion} · vence el '
                                '${_credito.fechaLimite}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        EstadoChip.de(_credito.condicion),
                      ],
                    ),
                    Divider(height: 22, color: palette.border),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Saldo pendiente',
                              style: theme.textTheme.bodyMedium),
                        ),
                        Text(formatCop(_credito.saldo),
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('DATOS DEL ABONO', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              CampoTexto(
                label: 'Monto a abonar (COP) *',
                hint: '500.000',
                controller: _monto,
                keyboardType: TextInputType.number,
                prefixText: '\$ ',
                readOnly: _pagoTotalObligatorio,
                inputFormatters: const [MilesFormatter()],
                errorText: errorMonto,
                helper: ayudaMonto,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text('Método de pago *', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < mediosPagoCliente.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _ChipMetodo(
                        label: mediosPagoCliente[i],
                        selected: mediosPagoCliente[i] == _metodo,
                        onTap: () => setState(() {
                          _metodo = mediosPagoCliente[i];
                          // El efectivo se paga en el local: no lleva soporte.
                          if (!_requiereSoporte) _comprobante = false;
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              if (errorMetodo != null) _TextoError(texto: errorMetodo),
              if (_requiereSoporte) ...[
                const SizedBox(height: 22),
                Text('SOPORTE DE LA CONSIGNACIÓN',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                const AvisoCaja(
                  icon: Icons.account_balance_outlined,
                  texto: 'Pide al asesor los datos de la cuenta para hacer '
                      'la transferencia.',
                ),
                const SizedBox(height: 12),
                InkWell(
                  key: const Key('abono-soporte'),
                  onTap: () => setState(() => _comprobante = !_comprobante),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 124,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: errorSoporte != null
                            ? palette.dangerFg
                            : _comprobante
                                ? AppColors.accent
                                : palette.border,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _comprobante
                              ? Icons.check_circle_outline
                              : Icons.add_photo_alternate_outlined,
                          size: 28,
                          color: _comprobante
                              ? palette.successFg
                              : palette.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _comprobante
                              ? 'comprobante.jpg · toca para quitarlo'
                              : 'Sube el pantallazo de la consignación '
                                  '(JPG o PNG)',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (errorSoporte != null) _TextoError(texto: errorSoporte),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('abono-guardar'),
                onPressed: _guardar,
                icon: const Icon(Icons.check, size: 19),
                label: const Text('Registrar abono'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextoError extends StatelessWidget {
  const _TextoError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        texto,
        style: TextStyle(
          color: context.palette.dangerFg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChipMetodo extends StatelessWidget {
  const _ChipMetodo({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.accentSoft : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmación tras registrar un abono.
class AbonoConfirmadoScreen extends StatelessWidget {
  const AbonoConfirmadoScreen({super.key, required this.abono});

  final Abono abono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: palette.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: palette.successFg, size: 40),
              ),
            ),
            const SizedBox(height: 22),
            Text('¡Abono registrado!', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${abono.id} · ${formatCop(abono.monto)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Quedó pendiente: un asesor validará el pago y, al '
              'confirmarlo, el saldo de tu crédito se actualiza.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Volver a Cartera'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Historial completo de abonos de un crédito.
class HistorialAbonosScreen extends StatelessWidget {
  const HistorialAbonosScreen({super.key, required this.credito});

  final Credito credito;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = CarteraStore.instance;

    return Column(
      children: [
        const MiraHeader(title: 'Historial de abonos'),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final abonos = credito.abonos;
              final porValidar =
                  abonos.where((a) => a.estado == abonoPendiente).length;
              return ListView(
                padding: margenPagina(context),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17375E),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total abonado',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatCop(credito.totalAprobado),
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${abonos.length} abonos · $porValidar por validar',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('ABONOS', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (abonos.isEmpty)
                    const _Vacio(texto: 'Este crédito todavía no tiene abonos.')
                  else
                    _ListaAbonos(credito: credito),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Detalle de un abono: cuánto se abonó, cómo va la validación y qué
/// comprobante quedó adjunto.
class DetalleAbonoScreen extends StatelessWidget {
  const DetalleAbonoScreen({super.key, required this.abono});

  final Abono abono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        const MiraHeader(title: 'Detalle del abono'),
        Expanded(
          child: ListView(
            padding: margenPagina(context),
            children: [
              MiraCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('MONTO ABONADO',
                              style: theme.textTheme.labelSmall),
                        ),
                        EstadoChip.de(abono.estado),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(formatCop(abono.monto),
                        style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text('${abono.id} · ${abono.credito}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (abono.estado == abonoRechazado) ...[
                const SizedBox(height: 12),
                AvisoCaja(
                  tono: EstadoTono.error,
                  texto: 'Motivo: '
                      '${abono.motivoRechazo ?? 'el comprobante no se pudo validar.'} '
                      'Vuelve a subir el abono desde la tarjeta del crédito.',
                ),
              ],
              if (abono.estado == abonoPendiente) ...[
                const SizedBox(height: 12),
                const AvisoCaja(
                  texto: 'Un asesor está validando el pago. Al confirmarlo, '
                      'el saldo de tu crédito se actualiza.',
                ),
              ],
              const SizedBox(height: 12),
              MiraCard(
                child: Column(
                  children: [
                    FilaDato(label: 'Crédito', value: abono.credito),
                    FilaDato(label: 'Fecha del pago', value: abono.fecha),
                    FilaDato(label: 'Método de pago', value: abono.metodo),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('COMPROBANTE DE PAGO', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              Container(
                height: 150,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      abono.conComprobante
                          ? Icons.image_outlined
                          : Icons.storefront_outlined,
                      size: 30,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      abono.conComprobante
                          ? 'comprobante.jpg'
                          : 'Este pago se hizo en el local, sin comprobante '
                              'adjunto.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Perfil del cliente con los mismos campos y reglas de "Mi perfil" en la
/// web: datos personales y, aparte, el cambio de contraseña.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final PerfilUsuario _perfil = PerfilUsuario.instance;

  bool _editando = false;

  /// Los avisos aparecen después del primer intento de guardar.
  bool _intentado = false;
  late String _tipoDocumento = _perfil.tipoDocumento;
  late final TextEditingController _nombre =
      TextEditingController(text: _perfil.nombre);
  late final TextEditingController _documento =
      TextEditingController(text: _perfil.documento);
  late final TextEditingController _correo =
      TextEditingController(text: _perfil.correo);
  late final TextEditingController _telefono =
      TextEditingController(text: _perfil.telefono);
  late final TextEditingController _direccion =
      TextEditingController(text: _perfil.direccion);
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _actual = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _correo.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _nueva.dispose();
    _actual.dispose();
    super.dispose();
  }

  void _cargar() {
    _tipoDocumento = _perfil.tipoDocumento;
    _nombre.text = _perfil.nombre;
    _documento.text = _perfil.documento;
    _correo.text = _perfil.correo;
    _telefono.text = _perfil.telefono;
    _direccion.text = _perfil.direccion;
    _nueva.clear();
    _actual.clear();
    _intentado = false;
  }

  void _editar() {
    setState(() {
      _cargar();
      _editando = true;
    });
  }

  void _cancelar() {
    setState(() {
      _cargar();
      _editando = false;
    });
  }

  bool get _cambiaCorreo =>
      _correo.text.trim().toLowerCase() != _perfil.correo.toLowerCase();

  String? get _errorNombre => _intentado && _nombre.text.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  String? get _errorDocumento => _intentado && _documento.text.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  String? get _errorCorreo => _intentado ? errorCorreo(_correo.text) : null;

  String? get _errorNueva =>
      _nueva.text.isEmpty ? null : errorPassword(_nueva.text);

  /// Para cambiar la contraseña o el correo hay que escribir la actual.
  String? get _errorActual =>
      _intentado && (_nueva.text.isNotEmpty || _cambiaCorreo) &&
              _actual.text.isEmpty
          ? 'Escribe tu contraseña actual para confirmar el cambio.'
          : null;

  void _guardar() {
    setState(() => _intentado = true);
    final hayError = [
      _errorNombre,
      _errorDocumento,
      _errorCorreo,
      _errorNueva,
      _errorActual,
    ].any((e) => e != null);
    if (hayError) return;

    setState(() {
      _perfil.tipoDocumento = _tipoDocumento;
      _perfil.nombre = _nombre.text.trim();
      _perfil.documento = _documento.text.trim();
      _perfil.correo = _correo.text.trim().toLowerCase();
      _perfil.telefono = _telefono.text.trim();
      _perfil.direccion = _direccion.text.trim();
      _editando = false;
    });
    mostrarAviso(context, 'Perfil actualizado');
  }

  void _cerrarSesion() {
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        const MiraHeader(title: 'Mi perfil', showBack: false),
        Expanded(
          child: ListView(
            padding: margenPagina(context, top: 22),
            children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17375E),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 3),
                  ),
                  child: Text(
                    _perfil.iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(_perfil.nombre, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(_perfil.correo, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 24),
              if (_editando)
                ..._formulario()
              else ...[
                Text('DATOS PERSONALES', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                MiraCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: _lectura(),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.dangerFg,
                  backgroundColor: palette.dangerSoft,
                  side: BorderSide(color: palette.dangerFg),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lectura() {
    final theme = Theme.of(context);
    final palette = context.palette;
    final filas = [
      ('DOCUMENTO', '${_perfil.tipoDocumento} ${_perfil.documento}'),
      ('NOMBRE COMPLETO', _perfil.nombre),
      ('DIRECCIÓN', _perfil.direccion),
      ('CORREO', _perfil.correo),
      ('TELÉFONO', _perfil.telefono),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filas[i].$1,
                  style:
                      theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  filas[i].$2.isEmpty ? '—' : filas[i].$2,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _editar,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.link,
            side: const BorderSide(color: AppColors.accent),
          ),
          child: const Text('Editar perfil'),
        ),
      ],
    );
  }

  List<Widget> _formulario() {
    final theme = Theme.of(context);
    void refrescar(String _) => setState(() {});

    return [
      Text('Actualiza tus datos de contacto y de facturación.',
          style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      Text('DATOS PERSONALES', style: theme.textTheme.labelSmall),
      const SizedBox(height: 12),
      MiraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo de documento *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < tiposDocumento.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ChipMetodo(
                      label: tiposDocumento[i],
                      selected: tiposDocumento[i] == _tipoDocumento,
                      onTap: () =>
                          setState(() => _tipoDocumento = tiposDocumento[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Número de documento *',
              controller: _documento,
              keyboardType: TextInputType.number,
              errorText: _errorDocumento,
              onChanged: refrescar,
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Nombre completo *',
              controller: _nombre,
              errorText: _errorNombre,
              onChanged: refrescar,
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Dirección',
              hint: 'Calle 50 #45-12, Medellín',
              controller: _direccion,
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Correo electrónico *',
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              errorText: _errorCorreo,
              onChanged: refrescar,
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Teléfono',
              controller: _telefono,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text('ACCESO', style: theme.textTheme.labelSmall),
      const SizedBox(height: 12),
      MiraCard(
        child: Column(
          children: [
            CampoTexto(
              label: 'Nueva contraseña',
              hint: 'Déjala vacía para no cambiarla',
              controller: _nueva,
              obscure: true,
              errorText: _errorNueva,
              helper: ayudaPassword,
              onChanged: refrescar,
            ),
            const SizedBox(height: 14),
            CampoTexto(
              label: 'Contraseña actual',
              hint: 'Solo si cambias la contraseña o el correo',
              controller: _actual,
              obscure: true,
              errorText: _errorActual,
              onChanged: refrescar,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelar,
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _guardar,
              child: const Text('Guardar perfil'),
            ),
          ),
        ],
      ),
    ];
  }
}

// ====================================================================
// 6. Rutas
// ====================================================================

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String recuperar = '/recuperar';
  static const String home = '/inicio';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      login => const LoginScreen(),
      recuperar => const RecuperarScreen(),
      home => const MainShell(),
      _ => const SplashScreen(),
    };
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}
