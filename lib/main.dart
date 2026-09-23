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
// Cotizaciones, Entregas y Perfil son solo visualización: muestran datos
// de ejemplo y no guardan nada. Cartera sí mantiene estado en memoria:
// registrar un abono baja el saldo pendiente y aparece en el historial,
// en el resumen de inicio y en el próximo pago.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}

// ====================================================================
// 1. Estado de Cartera
// ====================================================================

/// Un abono registrado sobre una cartera.
class Abono {
  const Abono({
    required this.monto,
    required this.fecha,
    required this.metodo,
    this.confirmado = true,
  });

  final int monto;
  final String fecha;
  final String metodo;
  final bool confirmado;
}

/// Cartera (crédito) del cliente.
class Cartera {
  Cartera({
    required this.codigo,
    required this.total,
    required this.abonado,
    required this.cuotaMensual,
    required this.inicio,
    required this.vence,
    required this.vencida,
    required List<Abono> abonos,
  }) : abonos = List<Abono>.of(abonos);

  final String codigo;
  final int total;
  int abonado;
  final int cuotaMensual;
  final String inicio;
  final String vence;
  final bool vencida;
  final List<Abono> abonos;

  int get pendiente => (total - abonado).clamp(0, total);

  double get progreso => total == 0 ? 0 : (abonado / total).clamp(0.0, 1.0);

  int get porcentaje => (progreso * 100).round();

  bool get alDia => !vencida;

  String get estado => vencida ? 'Vencido' : 'Al día';
}

/// Estado en memoria de las carteras. Es lo único que cambia de verdad
/// en la app: al registrar un abono, todas las pantallas que escuchan
/// este notificador se actualizan.
class CarteraStore extends ChangeNotifier {
  CarteraStore._();

  static final CarteraStore instance = CarteraStore._();

  final List<Cartera> carteras = [
    Cartera(
      codigo: 'CRD-2025-001',
      total: 4500000,
      abonado: 2100000,
      cuotaMensual: 350000,
      inicio: '1 abr. 2025',
      vence: '30 sep. 2025',
      vencida: false,
      abonos: const [
        Abono(monto: 350000, fecha: '1 ago. 2025', metodo: 'Transferencia'),
        Abono(monto: 350000, fecha: '1 jul. 2025', metodo: 'Transferencia'),
        Abono(monto: 200000, fecha: '3 jun. 2025', metodo: 'Efectivo'),
        Abono(monto: 150000, fecha: '1 jun. 2025', metodo: 'Transferencia'),
      ],
    ),
    Cartera(
      codigo: 'CRD-2025-002',
      total: 1800000,
      abonado: 1800000,
      cuotaMensual: 300000,
      inicio: '15 feb. 2025',
      vence: '15 ago. 2025',
      vencida: true,
      abonos: const [
        Abono(monto: 300000, fecha: '15 jul. 2025', metodo: 'Nequi'),
        Abono(monto: 300000, fecha: '15 jun. 2025', metodo: 'Nequi'),
      ],
    ),
  ];

  /// Cartera activa: la primera que todavía tiene saldo por pagar.
  /// Es la que alimenta el resumen de Inicio.
  Cartera get vigente => carteras.firstWhere(
        (c) => c.pendiente > 0,
        orElse: () => carteras.first,
      );

  int get cupoTotal => vigente.total;

  int get usado => vigente.abonado;

  int get disponible => vigente.pendiente;

  int get porcentajeUsado => vigente.porcentaje;

  /// Cartera cuya cuota está más próxima a vencer.
  Cartera? get proximoPago {
    for (final c in carteras) {
      if (c.pendiente > 0) return c;
    }
    return null;
  }

  /// Registra un abono: baja el pendiente y encabeza el historial.
  void registrarAbono({
    required Cartera cartera,
    required int monto,
    required String metodo,
  }) {
    if (monto <= 0) return;
    cartera.abonado = (cartera.abonado + monto).clamp(0, cartera.total);
    cartera.abonos.insert(
      0,
      Abono(monto: monto, fecha: _hoy(), metodo: metodo),
    );
    notifyListeners();
  }

  static String _hoy() {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.',
    ];
    final now = DateTime.now();
    return '${now.day} ${meses[now.month - 1]} ${now.year}';
  }
}

// ====================================================================
// 2. Tema
// ====================================================================

class AppColors {
  const AppColors._();

  static const Color accent = Color(0xFFF5B800);
  static const Color accentDark = Color(0xFFD99F00);
  static const Color onAccent = Color(0xFF1A1400);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static const MiraPalette dark = MiraPalette(
    background: Color(0xFF0D1520),
    surface: Color(0xFF162131),
    surfaceAlt: Color(0xFF1C2839),
    header: Color(0xFF16324F),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xBFFFFFFF),
    headerOverlay: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0xFF25344A),
    inputFill: Color(0xFF1B2739),
    iconTileBg: Color(0xFF1E2E44),
    iconTileFg: Color(0xFF8FB4E3),
    trackBg: Color(0xFF2B3A50),
    accentSoft: Color(0x1FF5B800),
    successSoft: Color(0x2E16A34A),
    warningSoft: Color(0x2ED97706),
    dangerSoft: Color(0x2EDC2626),
    shadow: Color(0x66000000),
    link: Color(0xFF60A5FA),
    isDark: true,
  );

  static const MiraPalette light = MiraPalette(
    background: Color(0xFFEEF2F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF6F9FC),
    header: Color(0xFF1E3A5F),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xCCFFFFFF),
    headerOverlay: Color(0x29FFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    inputFill: Color(0xFFF1F5F9),
    iconTileBg: Color(0xFFE8EFF8),
    iconTileFg: Color(0xFF2E5C8A),
    trackBg: Color(0xFFDDE5EE),
    accentSoft: Color(0x24F5B800),
    successSoft: Color(0x1F16A34A),
    warningSoft: Color(0x1FD97706),
    dangerSoft: Color(0x14DC2626),
    shadow: Color(0x24000000),
    link: Color(0xFF1E5FA8),
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
          foregroundColor: p.header,
          backgroundColor: p.surface,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: p.isDark ? p.border : p.header),
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
      color: palette.headerOverlay,
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
            color: palette.onHeader,
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

    return Container(
      width: double.infinity,
      color: palette.header,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canBack ? 8 : 20, 10, 12, 14),
          child: Row(
            children: [
              if (canBack)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back, color: palette.onHeader),
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
                            ?.copyWith(color: palette.onHeaderMuted),
                      ),
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.onHeader,
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

enum EstadoTono { exito, aviso, error, neutro }

/// Etiqueta redondeada de estado (Aprobada, Al día, Entregado...).
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.label, required this.tono});

  final String label;
  final EstadoTono tono;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color fg, Color bg) = switch (tono) {
      EstadoTono.exito => (AppColors.success, palette.successSoft),
      EstadoTono.aviso => (AppColors.warning, palette.warningSoft),
      EstadoTono.error => (AppColors.danger, palette.dangerSoft),
      EstadoTono.neutro => (palette.textSecondary, palette.surfaceAlt),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta blanca estándar de toda la app.
class MiraCard extends StatelessWidget {
  const MiraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Borde amarillo para las tarjetas destacadas de Inicio.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final decoration = BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlight ? AppColors.accent : palette.border,
        width: highlight ? 1.4 : 1,
      ),
      boxShadow: palette.isDark
          ? null
          : [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

/// Pestañas de la barra inferior.
enum MiraTab { inicio, cotizaciones, cartera, entregas, perfil }

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
  (
    icon: Icons.local_shipping_outlined,
    active: Icons.local_shipping,
    label: 'Entregas'
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
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
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
                      border: Border.all(color: palette.surface, width: 3),
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
                    selected ? AppColors.accentDark : palette.textSecondary,
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
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
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
// 4. Datos mock (Cotizaciones, Entregas, Perfil y carrusel)
// ====================================================================

class ItemCotizacion {
  const ItemCotizacion({
    required this.descripcion,
    required this.cantidad,
    required this.valorUnitario,
  });

  final String descripcion;
  final int cantidad;
  final int valorUnitario;

  int get subtotal => cantidad * valorUnitario;
}

class Cotizacion {
  const Cotizacion({
    required this.codigo,
    required this.fecha,
    required this.cliente,
    required this.tipo,
    required this.pago,
    required this.estado,
    required this.tono,
    required this.items,
  });

  final String codigo;
  final String fecha;
  final String cliente;
  final String tipo;
  final String pago;
  final String estado;
  final EstadoTono tono;
  final List<ItemCotizacion> items;

  int get total => items.fold(0, (sum, i) => sum + i.subtotal);
}

const List<Cotizacion> mockCotizaciones = [
  Cotizacion(
    codigo: 'COT-2025-001',
    fecha: '15 jul. 2025',
    cliente: 'Carlos Ramírez',
    tipo: 'Llanta nueva',
    pago: 'Crédito',
    estado: 'Aprobada',
    tono: EstadoTono.exito,
    items: [
      ItemCotizacion(
        descripcion: 'Llanta 205/65R15 Michelin',
        cantidad: 4,
        valorUnitario: 280000,
      ),
      ItemCotizacion(
        descripcion: 'Instalación y balanceo',
        cantidad: 4,
        valorUnitario: 20000,
      ),
    ],
  ),
  Cotizacion(
    codigo: 'COT-2025-002',
    fecha: '22 jul. 2025',
    cliente: 'Carlos Ramírez',
    tipo: 'Reencauche',
    pago: 'Contado',
    estado: 'Pendiente',
    tono: EstadoTono.aviso,
    items: [
      ItemCotizacion(
        descripcion: 'Reencauche 295/80R22.5',
        cantidad: 3,
        valorUnitario: 150000,
      ),
    ],
  ),
  Cotizacion(
    codigo: 'COT-2025-003',
    fecha: '3 ago. 2025',
    cliente: 'Carlos Ramírez',
    tipo: 'Llanta nueva',
    pago: 'Crédito',
    estado: 'Rechazada',
    tono: EstadoTono.error,
    items: [
      ItemCotizacion(
        descripcion: 'Llanta 225/45R17 Bridgestone',
        cantidad: 2,
        valorUnitario: 445000,
      ),
    ],
  ),
];

class Entrega {
  const Entrega({
    required this.codigo,
    required this.direccion,
    required this.fechaProgramada,
    required this.estado,
    required this.tono,
    required this.cotizacion,
    this.fechaEntrega,
    this.motivoCancelacion,
  });

  final String codigo;
  final String direccion;
  final String fechaProgramada;
  final String estado;
  final EstadoTono tono;
  final String cotizacion;
  final String? fechaEntrega;
  final String? motivoCancelacion;
}

const List<Entrega> mockEntregas = [
  Entrega(
    codigo: 'ENT-001',
    direccion: 'Cra. 45 #80-23, Medellín',
    fechaProgramada: '18 jul. 2025',
    fechaEntrega: '18 jul. 2025',
    estado: 'Entregado',
    tono: EstadoTono.exito,
    cotizacion: 'COT-2025-001',
  ),
  Entrega(
    codigo: 'ENT-002',
    direccion: 'Cl. 10 #5-67, El Poblado',
    fechaProgramada: '28 ago. 2025',
    estado: 'Programado',
    tono: EstadoTono.aviso,
    cotizacion: 'COT-2025-002',
  ),
  Entrega(
    codigo: 'ENT-003',
    direccion: 'Av. El Dorado #68C-61, Bogotá',
    fechaProgramada: '10 ago. 2025',
    estado: 'Cancelado',
    tono: EstadoTono.error,
    cotizacion: 'COT-2025-003',
    motivoCancelacion: 'Cliente solicitó cancelación por cambio de domicilio.',
  ),
];

/// Datos del cliente en sesión. Editables desde Perfil (en memoria).
class PerfilUsuario {
  PerfilUsuario._();

  static final PerfilUsuario instance = PerfilUsuario._();

  String nombre = 'Carlos Ramírez';
  String documento = '1023456789';
  String correo = 'carlos.ramirez@email.com';
  String telefono = '300 456 7890';
  String direccion = 'Cra. 45 #80-23, Medellín, Antioquia';

  String get iniciales {
    final partes = nombre.split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
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

/// Splash con el logo de MiraLlantas.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );

    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                Text(
                  'MiraLlantas',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: AppColors.onAccent,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gestión de llantas y reencauche',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onAccent.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: palette.header,
                  ),
                ),
              ],
            ),
          ),
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

/// Login. Sin selector de rol: la app es solo para el cliente.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _entrar() => Navigator.of(context).pushReplacementNamed(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoMira()),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'MiraLlantas',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Gestión de llantas y reencauche',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 30),
                  CampoTexto(
                    label: 'Correo electrónico',
                    hint: 'correo@ejemplo.com',
                    controller: _correo,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),
                  CampoTexto(
                    label: 'Contraseña',
                    hint: '••••••••',
                    controller: _clave,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _entrar(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.recuperar),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _entrar,
                    child: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 26),
                  const Center(child: SelectorTema()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora "Claro / Oscuro" del login.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OpcionTema(
            label: 'Claro',
            icon: Icons.light_mode_outlined,
            selected: !palette.isDark,
            onTap: () => ThemeController.instance.set(false),
          ),
          _OpcionTema(
            label: 'Oscuro',
            icon: Icons.dark_mode_outlined,
            selected: palette.isDark,
            onTap: () => ThemeController.instance.set(true),
          ),
        ],
      ),
    );
  }
}

class _OpcionTema extends StatelessWidget {
  const _OpcionTema({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = selected ? palette.textPrimary : palette.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuperar contraseña en tres pasos: correo, código y nueva clave.
class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  int _paso = 0;

  final TextEditingController _correo = TextEditingController();
  final List<TextEditingController> _digitos =
      List.generate(6, (_) => TextEditingController());
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    for (final d in _digitos) {
      d.dispose();
    }
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _avanzar() {
    if (_paso < 2) {
      setState(() => _paso++);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada (demo)')),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Recuperar contraseña'),
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
                          height: 3,
                          decoration: BoxDecoration(
                            color: i <= _paso
                                ? palette.header
                                : palette.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 26),
                if (_paso == 0) ...[
                  Text('Ingresa tu correo',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(
                    'Te enviaremos un código de verificación de 6 dígitos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  CampoTexto(
                    label: 'Correo electrónico',
                    hint: 'correo@ejemplo.com',
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _avanzar,
                    child: const Text('Enviar código'),
                  ),
                ] else if (_paso == 1) ...[
                  Text('Código de verificación',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(
                    'Revisa tu correo e ingresa el código de 6 dígitos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: TextField(
                              controller: _digitos[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: theme.textTheme.titleLarge,
                              decoration: const InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _avanzar,
                    child: const Text('Verificar código'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('¿No recibiste el código? Reenviar'),
                    ),
                  ),
                ] else ...[
                  Text('Nueva contraseña',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(
                    'Elige una contraseña segura de al menos 6 caracteres.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  CampoTexto(
                    label: 'Nueva contraseña',
                    hint: '••••••••',
                    controller: _nueva,
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  CampoTexto(
                    label: 'Confirmar contraseña',
                    hint: '••••••••',
                    controller: _confirmar,
                    obscure: true,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _avanzar,
                    child: const Text('Actualizar contraseña'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenedor principal: cinco pestañas, cada una con su propio
/// Navigator para que la barra inferior no se pierda al entrar a un
/// detalle.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MiraTab _tab = MiraTab.inicio;

  final Map<MiraTab, GlobalKey<NavigatorState>> _keys = {
    for (final t in MiraTab.values) t: GlobalKey<NavigatorState>(),
  };

  void _select(MiraTab tab) {
    if (tab == _tab) {
      // Volver a tocar la pestaña activa regresa a su pantalla raíz.
      _keys[tab]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _tab = tab);
  }

  Widget _raiz(MiraTab tab) => switch (tab) {
        MiraTab.inicio => const InicioScreen(),
        MiraTab.cotizaciones => const CotizacionesScreen(),
        MiraTab.cartera => const CarteraScreen(),
        MiraTab.entregas => const EntregasScreen(),
        MiraTab.perfil => const PerfilScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _keys[_tab]!.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else if (_tab != MiraTab.inicio) {
            setState(() => _tab = MiraTab.inicio);
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

/// Pantalla de Inicio: resumen de cartera, accesos y carrusel.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final store = CarteraStore.instance;

    return Column(
      children: [
        MiraHeader(
          title: PerfilUsuario.instance.nombre,
          subtitle: 'Bienvenido de nuevo,',
          showBack: false,
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final proximo = store.proximoPago;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  MiraCard(
                    highlight: true,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Saldo de Cartera disponible',
                                      style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 6),
                                  Text(formatCop(store.disponible),
                                      style: theme.textTheme.headlineLarge),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: palette.accentSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.credit_card,
                                color: AppColors.accentDark,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Usado: ${formatCop(store.usado)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cupo total: ${formatCop(store.cupoTotal)}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BarraProgreso(value: store.porcentajeUsado / 100),
                        const SizedBox(height: 8),
                        Text(
                          '${store.porcentajeUsado}% del cupo utilizado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.accentDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniCard(
                          icon: Icons.description_outlined,
                          titulo: 'COTIZACIONES',
                          valor: '${mockCotizaciones.length}',
                          detalle: 'activas este mes',
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: _MiniCard(
                          icon: Icons.local_shipping_outlined,
                          titulo: 'ENTREGAS',
                          valor: '1',
                          detalle: 'pendiente de entrega',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (proximo != null) _CardProximoPago(cartera: proximo),
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

class _CardProximoPago extends StatelessWidget {
  const _CardProximoPago({required this.cartera});

  final Cartera cartera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return MiraCard(
      highlight: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Próximo pago', style: theme.textTheme.bodyMedium),
                Text(
                  formatCop(cartera.cuotaMensual),
                  style: theme.textTheme.headlineLarge?.copyWith(fontSize: 24),
                ),
                Text(
                  'Cuota ${cartera.codigo} · vence ${cartera.vence}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.detalle,
  });

  final IconData icon;
  final String titulo;
  final String valor;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return MiraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.iconTileFg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(valor,
              style: theme.textTheme.headlineLarge?.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
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

/// Listado de cotizaciones (solo visualización).
class CotizacionesScreen extends StatelessWidget {
  const CotizacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        const MiraHeader(title: 'Cotizaciones', showBack: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text('${mockCotizaciones.length} COTIZACIONES',
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              for (final cot in mockCotizaciones) ...[
                MiraCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CotizacionDetalleScreen(cotizacion: cot),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cot.codigo,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('${cot.fecha} · ${cot.pago} · ${cot.tipo}',
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 10),
                            EstadoChip(label: cot.estado, tono: cot.tono),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(formatCop(cot.total),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontSize: 16)),
                      Icon(Icons.chevron_right, color: palette.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Detalle de una cotización con sus ítems.
class CotizacionDetalleScreen extends StatelessWidget {
  const CotizacionDetalleScreen({super.key, required this.cotizacion});

  final Cotizacion cotizacion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        MiraHeader(title: cotizacion.codigo),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              MiraCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(cotizacion.fecha,
                              style: theme.textTheme.bodyMedium),
                        ),
                        EstadoChip(
                          label: cotizacion.estado,
                          tono: cotizacion.tono,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilaDato(label: 'Cliente', value: cotizacion.cliente),
                    FilaDato(label: 'Tipo', value: cotizacion.tipo),
                    FilaDato(label: 'Pago', value: cotizacion.pago),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('ÍTEMS DE LA COTIZACIÓN', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              MiraCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text('DESCRIPCIÓN',
                              style: theme.textTheme.labelSmall),
                        ),
                        Expanded(
                          child: Text('CANT.',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('SUBTOTAL',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall),
                        ),
                      ],
                    ),
                    for (final item in cotizacion.items) ...[
                      Divider(height: 22, color: palette.border),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(item.descripcion,
                                style: theme.textTheme.bodyLarge),
                          ),
                          Expanded(
                            child: Text('${item.cantidad}',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyLarge),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCop(item.valorUnitario),
                                    style: theme.textTheme.bodySmall),
                                const SizedBox(height: 2),
                                Text(formatCop(item.subtotal),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    Divider(height: 24, color: palette.border),
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text('Total', style: theme.textTheme.titleMedium),
                        ),
                        Text(
                          formatCop(cotizacion.total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color:
                                palette.isDark ? palette.link : palette.header,
                            fontSize: 21,
                          ),
                        ),
                      ],
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

/// Listado de carteras. Único módulo con funcionalidad real.
class CarteraScreen extends StatelessWidget {
  const CarteraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = CarteraStore.instance;

    return Column(
      children: [
        const MiraHeader(title: 'Mi Cartera', showBack: false),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                Text('${store.carteras.length} CARTERAS',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                for (final cartera in store.carteras) ...[
                  _CarteraCard(cartera: cartera),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CarteraCard extends StatelessWidget {
  const _CarteraCard({required this.cartera});

  final Cartera cartera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return MiraCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CarteraDetalleScreen(cartera: cartera),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(cartera.codigo, style: theme.textTheme.titleMedium),
              ),
              EstadoChip(
                label: cartera.estado,
                tono: cartera.vencida ? EstadoTono.error : EstadoTono.exito,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Vence: ${cartera.vence}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'Pendiente: '),
                      TextSpan(
                        text: formatCop(cartera.pendiente),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Total: ${formatCop(cartera.total)}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          BarraProgreso(
            value: cartera.progreso,
            height: 7,
            color: cartera.vencida ? AppColors.danger : palette.header,
          ),
          const SizedBox(height: 8),
          Text(
            '${cartera.porcentaje}% abonado · Cuota: '
            '${formatCop(cartera.cuotaMensual)} / mes',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Detalle de una cartera con accesos a abono e historial.
class CarteraDetalleScreen extends StatelessWidget {
  const CarteraDetalleScreen({super.key, required this.cartera});

  final Cartera cartera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = CarteraStore.instance;

    return Column(
      children: [
        MiraHeader(title: cartera.codigo),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                          EstadoChip(
                            label: cartera.estado,
                            tono: cartera.vencida
                                ? EstadoTono.error
                                : EstadoTono.exito,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(formatCop(cartera.pendiente),
                          style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 16),
                      BarraProgreso(
                        value: cartera.progreso,
                        color: cartera.vencida
                            ? AppColors.danger
                            : AppColors.accent,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: DatoCompacto(
                              label: 'Valor total',
                              value: formatCop(cartera.total),
                            ),
                          ),
                          Expanded(
                            child: DatoCompacto(
                              label: 'Abonado',
                              value: formatCop(cartera.abonado),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DatoCompacto(
                              label: 'Cuota mensual',
                              value: '${formatCop(cartera.cuotaMensual)} / mes',
                            ),
                          ),
                          Expanded(
                            child: DatoCompacto(
                              label: 'Inicio',
                              value: cartera.inicio,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DatoCompacto(
                              label: 'Vence',
                              value: cartera.vence,
                            ),
                          ),
                          Expanded(
                            child: DatoCompacto(
                              label: 'Progreso',
                              value: '${cartera.porcentaje}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: cartera.pendiente == 0
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RegistrarAbonoScreen(cartera: cartera),
                                  ),
                                ),
                        child: const Text('Registrar abono'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HistorialAbonosScreen(
                              cartera: cartera,
                            ),
                          ),
                        ),
                        child: const Text('Ver historial'),
                      ),
                    ),
                  ],
                ),
                if (cartera.pendiente == 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Esta cartera ya está pagada por completo.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Registrar abono: el único formulario que cambia datos de verdad.
class RegistrarAbonoScreen extends StatefulWidget {
  const RegistrarAbonoScreen({super.key, required this.cartera});

  final Cartera cartera;

  @override
  State<RegistrarAbonoScreen> createState() => _RegistrarAbonoScreenState();
}

class _RegistrarAbonoScreenState extends State<RegistrarAbonoScreen> {
  static const List<String> metodos = [
    'Transferencia',
    'Efectivo',
    'Nequi',
    'Daviplata',
  ];

  final TextEditingController _monto = TextEditingController();
  int _metodo = 0;
  bool _comprobante = false;

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  int get _valor => int.tryParse(_monto.text.trim()) ?? 0;

  bool get _valido => _valor > 0 && _valor <= widget.cartera.pendiente;

  void _guardar() {
    final monto = _valor;
    CarteraStore.instance.registrarAbono(
      cartera: widget.cartera,
      monto: monto,
      metodo: metodos[_metodo],
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AbonoConfirmadoScreen(monto: monto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final excede = _valor > widget.cartera.pendiente;

    return Column(
      children: [
        const MiraHeader(title: 'Registrar abono'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            children: [
              CampoTexto(
                label: 'Monto del abono (COP)',
                hint: '350000',
                controller: _monto,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 6),
              Text(
                excede
                    ? 'El abono supera el saldo pendiente '
                        '(${formatCop(widget.cartera.pendiente)}).'
                    : 'Saldo pendiente: '
                        '${formatCop(widget.cartera.pendiente)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: excede ? AppColors.danger : palette.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              Text('Método de pago', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < metodos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _ChipMetodo(
                        label: metodos[i],
                        selected: i == _metodo,
                        onTap: () => setState(() => _metodo = i),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text('Comprobante de pago', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _comprobante = !_comprobante),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 116,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _comprobante
                            ? Icons.check_circle_outline
                            : Icons.upload_outlined,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _comprobante
                            ? 'comprobante.jpg'
                            : 'Subir comprobante',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _valido ? _guardar : null,
                child: const Text('Guardar abono'),
              ),
            ],
          ),
        ),
      ],
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
      color: selected ? palette.surfaceAlt : palette.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.header : palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
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
  const AbonoConfirmadoScreen({super.key, required this.monto});

  final int monto;

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
                child: const Icon(
                  Icons.check,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('¡Abono registrado!', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'Tu abono por '),
                  TextSpan(
                    text: formatCop(monto),
                    style: theme.textTheme.titleMedium,
                  ),
                  const TextSpan(text: ' fue enviado para verificación.'),
                ],
              ),
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

/// Historial de abonos de una cartera.
class HistorialAbonosScreen extends StatelessWidget {
  const HistorialAbonosScreen({super.key, required this.cartera});

  final Cartera cartera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final store = CarteraStore.instance;

    return Column(
      children: [
        const MiraHeader(title: 'Historial de abonos'),
        Expanded(
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final abonos = cartera.abonos;
              final total = abonos.fold(0, (sum, a) => sum + a.monto);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.header,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total abonado',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: palette.onHeaderMuted)),
                        const SizedBox(height: 6),
                        Text(formatCop(total),
                            style: theme.textTheme.headlineLarge
                                ?.copyWith(color: palette.onHeader)),
                        const SizedBox(height: 4),
                        Text('${abonos.length} transacciones',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: palette.onHeaderMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('TRANSACCIONES', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  for (final abono in abonos) ...[
                    MiraCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatCop(abono.monto),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontSize: 17)),
                                const SizedBox(height: 4),
                                Text('${abono.fecha} · ${abono.metodo}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          EstadoChip(
                            label: abono.confirmado
                                ? 'Confirmado'
                                : 'En verificación',
                            tono: abono.confirmado
                                ? EstadoTono.exito
                                : EstadoTono.aviso,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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

/// Listado de entregas (solo visualización).
class EntregasScreen extends StatelessWidget {
  const EntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        const MiraHeader(title: 'Entregas', showBack: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text('${mockEntregas.length} ENTREGAS',
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              for (final entrega in mockEntregas) ...[
                MiraCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EntregaDetalleScreen(entrega: entrega),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entrega.codigo,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${entrega.direccion} · '
                              '${entrega.fechaProgramada}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            EstadoChip(
                              label: entrega.estado,
                              tono: entrega.tono,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: palette.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Detalle de una entrega: datos, evidencia o motivo de cancelación.
class EntregaDetalleScreen extends StatelessWidget {
  const EntregaDetalleScreen({super.key, required this.entrega});

  final Entrega entrega;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final cancelada = entrega.motivoCancelacion != null;

    return Column(
      children: [
        MiraHeader(title: entrega.codigo),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              MiraCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Estado de entrega',
                              style: theme.textTheme.titleMedium),
                        ),
                        EstadoChip(label: entrega.estado, tono: entrega.tono),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilaDato(label: 'Cotización', value: entrega.cotizacion),
                    FilaDato(label: 'Dirección', value: entrega.direccion),
                    FilaDato(
                      label: 'Fecha programada',
                      value: entrega.fechaProgramada,
                    ),
                    if (entrega.fechaEntrega != null)
                      FilaDato(
                        label: 'Fecha de entrega',
                        value: entrega.fechaEntrega!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (cancelada) ...[
                Text('MOTIVO DE CANCELACIÓN',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.dangerSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Text(
                    entrega.motivoCancelacion!,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.danger),
                  ),
                ),
              ] else ...[
                Text('EVIDENCIA FOTOGRÁFICA',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_outlined,
                          size: 32, color: palette.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        entrega.fechaEntrega != null
                            ? 'Foto de entrega disponible'
                            : 'Sin evidencia registrada',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Perfil del cliente con edición en la misma pantalla.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final PerfilUsuario _perfil = PerfilUsuario.instance;

  bool _editando = false;
  late TextEditingController _nombre;
  late TextEditingController _documento;
  late TextEditingController _correo;
  late TextEditingController _telefono;
  late TextEditingController _direccion;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: _perfil.nombre);
    _documento = TextEditingController(text: _perfil.documento);
    _correo = TextEditingController(text: _perfil.correo);
    _telefono = TextEditingController(text: _perfil.telefono);
    _direccion = TextEditingController(text: _perfil.direccion);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _correo.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  void _cancelar() {
    setState(() {
      _nombre.text = _perfil.nombre;
      _documento.text = _perfil.documento;
      _correo.text = _perfil.correo;
      _telefono.text = _perfil.telefono;
      _direccion.text = _perfil.direccion;
      _editando = false;
    });
  }

  void _guardar() {
    setState(() {
      _perfil.nombre = _nombre.text.trim();
      _perfil.documento = _documento.text.trim();
      _perfil.correo = _correo.text.trim();
      _perfil.telefono = _telefono.text.trim();
      _perfil.direccion = _direccion.text.trim();
      _editando = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Perfil actualizado (demo)')),
      );
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
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: palette.header,
                  child: Text(
                    _perfil.iniciales,
                    style: TextStyle(
                      color: palette.onHeader,
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
              Text('INFORMACIÓN PERSONAL', style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              MiraCard(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: _editando ? _formulario() : _lectura(),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  backgroundColor: palette.dangerSoft,
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lectura() {
    final palette = context.palette;
    final filas = [
      ('NOMBRE COMPLETO', _perfil.nombre),
      ('DOCUMENTO', _perfil.documento),
      ('CORREO', _perfil.correo),
      ('TELÉFONO', _perfil.telefono),
      ('DIRECCIÓN', _perfil.direccion),
    ];

    return Column(
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(filas[i].$1,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(filas[i].$2,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() => _editando = true),
          child: const Text('Editar perfil'),
        ),
      ],
    );
  }

  Widget _formulario() {
    return Column(
      children: [
        const SizedBox(height: 10),
        CampoTexto(label: 'Nombre completo', controller: _nombre),
        const SizedBox(height: 14),
        CampoTexto(
          label: 'Número de documento',
          controller: _documento,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        CampoTexto(
          label: 'Correo electrónico',
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        CampoTexto(
          label: 'Teléfono',
          controller: _telefono,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        CampoTexto(label: 'Dirección', controller: _direccion),
        const SizedBox(height: 20),
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
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ],
    );
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
