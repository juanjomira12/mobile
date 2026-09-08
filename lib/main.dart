// MiraLlantas — frontend móvil (solo UI, sin backend ni persistencia).
//
// Todo el prototipo vive en este único archivo, ordenado por secciones:
//   1. Arranque (main + MaterialApp)
//   2. Tema: paleta, ThemeData y control de modo claro/oscuro
//   3. Widgets compartidos
//   4. Datos mock
//   5. Rutas
//   6. Pantallas
//
// Los widgets nunca declaran colores literales: los leen del tema con
// `Theme.of(context)` o del atajo `context.palette`.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
// core/theme/app_colors.dart
// ====================================================================

/// Paleta única de MiraLlantas.
///
/// Todos los colores de la app salen de aquí: los widgets nunca declaran
/// colores literales, sino que los leen del [ThemeData] construido en
/// `app_theme.dart` o de la [MiraPalette] activa.
class AppColors {
  const AppColors._();

  /// Amarillo de marca. Es el mismo en tema claro y oscuro.
  static const Color accent = Color(0xFFF5B800);
  static const Color accentDark = Color(0xFFD99F00);

  /// Color del texto que se dibuja encima del amarillo.
  static const Color onAccent = Color(0xFF1A1400);

  // Estados (compartidos por ambos temas).
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF60A5FA);
  static const Color warning = Color(0xFFF59E0B);

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
    dangerSoft: Color(0x2EEF4444),
    successSoft: Color(0x2E22C55E),
    warningSoft: Color(0x2EF59E0B),
    shadow: Color(0x66000000),
    link: info,
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
    inputFill: Color(0xFFEFF3F8),
    iconTileBg: Color(0xFFE8EFF8),
    iconTileFg: Color(0xFF2E5C8A),
    trackBg: Color(0xFFDDE5EE),
    accentSoft: Color(0x24F5B800),
    dangerSoft: Color(0x1FEF4444),
    successSoft: Color(0x1F22C55E),
    warningSoft: Color(0x24F59E0B),
    shadow: Color(0x2E000000),
    link: Color(0xFF1E5FA8),
    isDark: false,
  );
}

/// Conjunto de colores de una variante del tema (oscuro o claro).
///
/// Se expone a los widgets como [ThemeExtension]: se accede con
/// `Theme.of(context).extension<MiraPalette>()!` o con el atajo
/// `context.palette` definido en `app_theme.dart`.
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
    required this.dangerSoft,
    required this.successSoft,
    required this.warningSoft,
    required this.shadow,
    required this.link,
    required this.isDark,
  });

  /// Fondo general de las pantallas.
  final Color background;

  /// Fondo de tarjetas y campos elevados.
  final Color surface;
  final Color surfaceAlt;

  /// Azul marino de las cabeceras y su contenido.
  final Color header;
  final Color onHeader;
  final Color onHeaderMuted;

  /// Velo claro para botones dibujados sobre la cabecera.
  final Color headerOverlay;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color inputFill;

  /// Cuadro de icono de las tarjetas de módulo.
  final Color iconTileBg;
  final Color iconTileFg;

  /// Fondo de las barras de progreso.
  final Color trackBg;

  /// Amarillo y rojo translúcidos para estados seleccionados/destructivos.
  final Color accentSoft;
  final Color dangerSoft;
  final Color successSoft;
  final Color warningSoft;

  final Color shadow;
  final Color link;
  final bool isDark;

  @override
  MiraPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? header,
    Color? onHeader,
    Color? onHeaderMuted,
    Color? headerOverlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? inputFill,
    Color? iconTileBg,
    Color? iconTileFg,
    Color? trackBg,
    Color? accentSoft,
    Color? dangerSoft,
    Color? successSoft,
    Color? warningSoft,
    Color? shadow,
    Color? link,
    bool? isDark,
  }) {
    return MiraPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      header: header ?? this.header,
      onHeader: onHeader ?? this.onHeader,
      onHeaderMuted: onHeaderMuted ?? this.onHeaderMuted,
      headerOverlay: headerOverlay ?? this.headerOverlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
      iconTileBg: iconTileBg ?? this.iconTileBg,
      iconTileFg: iconTileFg ?? this.iconTileFg,
      trackBg: trackBg ?? this.trackBg,
      accentSoft: accentSoft ?? this.accentSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      successSoft: successSoft ?? this.successSoft,
      warningSoft: warningSoft ?? this.warningSoft,
      shadow: shadow ?? this.shadow,
      link: link ?? this.link,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  MiraPalette lerp(ThemeExtension<MiraPalette>? other, double t) {
    if (other is! MiraPalette) return this;
    return MiraPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      header: Color.lerp(header, other.header, t)!,
      onHeader: Color.lerp(onHeader, other.onHeader, t)!,
      onHeaderMuted: Color.lerp(onHeaderMuted, other.onHeaderMuted, t)!,
      headerOverlay: Color.lerp(headerOverlay, other.headerOverlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      iconTileBg: Color.lerp(iconTileBg, other.iconTileBg, t)!,
      iconTileFg: Color.lerp(iconTileFg, other.iconTileFg, t)!,
      trackBg: Color.lerp(trackBg, other.trackBg, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      link: Color.lerp(link, other.link, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

// ====================================================================
// core/theme/app_theme.dart
// ====================================================================

/// Construye los [ThemeData] claro y oscuro a partir de [AppColors].
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
      appBarTheme: AppBarTheme(
        backgroundColor: p.header,
        foregroundColor: p.onHeader,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.onHeader,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
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
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.link,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: p.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
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
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: p.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: p.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: p.textMuted, fontSize: 12),
      labelLarge: TextStyle(
        color: p.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: p.textMuted,
        fontSize: 12,
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

/// Atajo para leer la paleta activa desde cualquier widget.
extension MiraThemeContext on BuildContext {
  MiraPalette get palette => Theme.of(this).extension<MiraPalette>()!;
}

// ====================================================================
// core/theme/theme_controller.dart
// ====================================================================

/// Controla el [ThemeMode] de la app (solo en memoria: sin persistencia).
///
/// Lo consume `main.dart` con un [ValueListenableBuilder] y lo alternan los
/// botones de tema de las cabeceras.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.dark);

  static final ThemeController instance = ThemeController._();

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

// ====================================================================
// core/format/currency.dart
// ====================================================================

/// Formatea un entero como pesos colombianos: `1200000` -> `$ 1.200.000`.
String formatCop(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}\$ $buffer';
}

// ====================================================================
// core/widgets/status_chip.dart
// ====================================================================

/// Tono semántico de un estado (cotización, crédito, entrega, abono).
enum StatusTone { success, warning, danger, neutral }

/// Etiqueta redondeada de estado: "Aprobada", "Vencido", "Programado"...
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (Color fg, Color bg) = switch (tone) {
      StatusTone.success => (AppColors.success, palette.successSoft),
      StatusTone.warning => (AppColors.warning, palette.warningSoft),
      StatusTone.danger => (AppColors.danger, palette.dangerSoft),
      StatusTone.neutral => (palette.textSecondary, palette.surfaceAlt),
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

// ====================================================================
// core/widgets/theme_toggle_button.dart
// ====================================================================

/// Botón cuadrado de sol/luna que alterna el [ThemeMode] de la app.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.onHeader = true});

  /// `true` cuando se dibuja sobre la cabecera azul.
  final bool onHeader;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color fg = onHeader ? palette.onHeader : palette.textSecondary;

    return Material(
      color: onHeader ? palette.headerOverlay : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: ThemeController.instance.toggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            palette.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: fg,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// core/widgets/mira_header.dart
// ====================================================================

/// Cabecera azul marino con título, botón de volver opcional y el
/// interruptor de tema. La usan todas las pantallas interiores.
class MiraHeader extends StatelessWidget {
  const MiraHeader({
    super.key,
    required this.title,
    this.showBack,
    this.action,
  });

  final String title;

  /// Si es `null` el botón de volver aparece solo cuando la ruta se
  /// puede desapilar, de modo que las pantallas raíz de la barra
  /// inferior salgan sin flecha.
  final bool? showBack;

  /// Widget extra a la izquierda del botón de tema (por ejemplo un botón
  /// de "Nueva").
  final Widget? action;

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
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.onHeader,
                  ),
                ),
              ),
              if (action != null) ...[action!, const SizedBox(width: 8)],
              const ThemeToggleButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/Auth/presentation/widgets/mira_logo.dart
// ====================================================================




/// Logo de MiraLlantas: un rin dibujado dentro de una tarjeta redondeada.
///
/// Se usa en el splash y en el login. Al ser vectorial no depende de
/// ningun asset externo.
class MiraLogo extends StatelessWidget {
  const MiraLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.header,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.56),
          painter: _WheelPainter(),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  static const Color _tire = Color(0xFF11151C);
  static const Color _rim = Color(0xFFC9D2DC);
  static const Color _accentRing = Color(0xFF7A2E3E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(center, r, Paint()..color = _tire);
    canvas.drawCircle(
      center,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = _accentRing,
    );
    canvas.drawCircle(center, r * 0.72, Paint()..color = _rim);
    canvas.drawCircle(center, r * 0.60, Paint()..color = _tire);

    // Cinco radios del rin.
    final spoke = Paint()
      ..color = _rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final end = Offset(
        center.dx + r * 0.52 * math.cos(angle),
        center.dy + r * 0.52 * math.sin(angle),
      );
      canvas.drawLine(center, end, spoke);
    }
    canvas.drawCircle(center, r * 0.16, Paint()..color = _rim);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ====================================================================
// Features/Auth/presentation/widgets/custom_text_field.dart
// ====================================================================

/// Campo de texto reutilizable en todos los formularios de la app.
///
/// Toma su apariencia del `inputDecorationTheme`, por lo que no declara
/// colores propios.
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;

  /// Si es `true` el campo nace oculto y muestra el boton de ojo.
  final bool obscure;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
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
          enabled: widget.enabled,
          obscureText: _hidden,
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
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _hidden ? 'Mostrar' : 'Ocultar',
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Features/Auth/presentation/widgets/custom_button.dart
// ====================================================================

/// Boton reutilizable con las dos variantes que usa la app:
/// solida (amarillo de marca) y contorneada.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.filled,
  });

  const CustomButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  }) : variant = ButtonVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    // `scaleDown` evita que una etiqueta larga parta el botón en dos
    // líneas en pantallas angostas.
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(this.label, maxLines: 1),
    );
    final child = icon == null
        ? label
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Flexible(child: label),
            ],
          );

    if (variant == ButtonVariant.outlined) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }
    return ElevatedButton(onPressed: onPressed, child: child);
  }
}

enum ButtonVariant { filled, outlined }

// ====================================================================
// Features/Auth/presentation/widgets/role_selector.dart
// ====================================================================

/// Roles disponibles en el login. Determina a que dashboard se navega.
enum UserRole { usuario, administrador }

extension UserRoleLabel on UserRole {
  String get label =>
      this == UserRole.usuario ? 'Usuario' : 'Administrador';
}

/// Selector tipo segmented control para elegir el rol antes de entrar.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acceder como', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: palette.inputFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final role in UserRole.values)
                Expanded(
                  child: _RoleTab(
                    role: role,
                    selected: role == value,
                    onTap: () => onChanged(role),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selectedFill = palette.accentSoft;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedFill : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Text(
          role.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (palette.isDark ? AppColors.accent : AppColors.accentDark)
                : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/dashboard/presentation/widgets/mira_bottom_nav.dart
// ====================================================================

/// Barra inferior comun a los dos dashboards.
class MiraBottomNav extends StatelessWidget {
  const MiraBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<BottomNavigationBarItem> items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.description_outlined),
      activeIcon: Icon(Icons.description),
      label: 'Cotizaciones',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.credit_card_outlined),
      activeIcon: Icon(Icons.credit_card),
      label: 'Créditos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_shipping_outlined),
      activeIcon: Icon(Icons.local_shipping),
      label: 'Entregas',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          items: items,
        ),
      ),
    );
  }
}

/// Barra inferior autónoma: deduce la pestaña activa de la ruta actual y
/// navega sola. Se pone en `bottomNavigationBar` de cada pantalla para
/// que la barra siga visible en toda la app.
class MiraTabBar extends StatelessWidget {
  const MiraTabBar({super.key});

  /// Ruta raíz de cada pestaña (`null` = Inicio, que es la ruta base).
  static const List<String?> tabRoutes = [
    null,
    AppRoutes.quotes,
    AppRoutes.credits,
    AppRoutes.deliveries,
    AppRoutes.profile,
  ];

  /// Pestaña que corresponde a cada ruta interior.
  static const Map<String, int> _indexByRoute = {
    AppRoutes.userDashboard: 0,
    AppRoutes.adminDashboard: 0,
    AppRoutes.quotes: 1,
    AppRoutes.newQuote: 1,
    AppRoutes.quoteDetail: 1,
    AppRoutes.credits: 2,
    AppRoutes.creditDetail: 2,
    AppRoutes.newPayment: 2,
    AppRoutes.paymentsHistory: 2,
    AppRoutes.deliveries: 3,
    AppRoutes.deliveryDetail: 3,
    AppRoutes.profile: 4,
    AppRoutes.editProfile: 4,
  };

  /// Vuelve a la raíz (el dashboard) y abre la pestaña pedida.
  static void goToTab(BuildContext context, int index) {
    final route = tabRoutes[index];
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    if (route != null) navigator.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final name = ModalRoute.of(context)?.settings.name;
    return MiraBottomNav(
      currentIndex: _indexByRoute[name] ?? 0,
      onTap: (index) => goToTab(context, index),
    );
  }
}

// ====================================================================
// Features/dashboard/presentation/widgets/module_card.dart
// ====================================================================

/// Definicion de un modulo de la grilla del dashboard (datos mock).
class ModuleItem {
  const ModuleItem({
    required this.label,
    required this.icon,
    this.standout = false,
    this.onTap,
  });

  final String label;
  final IconData icon;

  /// Resalta la tarjeta con el amarillo institucional (se usa para
  /// "Cerrar sesión", que no es una acción destructiva).
  final bool standout;
  final VoidCallback? onTap;
}

/// Tarjeta cuadrada con icono outline y etiqueta, usada en la grilla
/// de modulos de ambos dashboards.
class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.item});

  final ModuleItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final Color iconBg =
        item.standout ? palette.accentSoft : palette.iconTileBg;
    final Color iconFg =
        item.standout ? AppColors.accentDark : palette.iconTileFg;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.standout ? AppColors.accent : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: iconFg, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                item.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/dashboard/presentation/widgets/dashboard_header.dart
// ====================================================================

/// Cabecera azul marino del dashboard con el saludo y el botón de tema.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.name,
    this.roleLabel,
  });

  final String name;

  /// Texto amarillo bajo el nombre (por ejemplo "ADMINISTRADOR").
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: palette.header,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido de nuevo,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.onHeaderMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.onHeader,
                        fontSize: 22,
                      ),
                    ),
                    if (roleLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        roleLabel!,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
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

// ====================================================================
// Features/dashboard/presentation/widgets/credit_balance_card.dart
// ====================================================================

/// Tarjeta destacada del dashboard de Usuario: saldo en credito
/// disponible y barra de cupo usado.
class CreditBalanceCard extends StatelessWidget {
  const CreditBalanceCard({
    super.key,
    required this.available,
    required this.used,
    required this.total,
  });

  final int available;
  final int used;
  final int total;

  double get _progress => total == 0 ? 0 : used / total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final percent = (_progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
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
                    Text(
                      'Saldo en crédito disponible',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCop(available),
                      style: theme.textTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: AppColors.onAccent,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Usado: ${formatCop(used)}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cupo total: ${formatCop(total)}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: palette.trackBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent% del cupo utilizado',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.accentDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Features/dashboard/presentation/widgets/admin_summary_card.dart
// ====================================================================

/// Una celda del resumen operativo: numero grande + descripcion.
class SummaryStat {
  const SummaryStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;

  /// Pinta el numero en rojo (indicadores que requieren atencion).
  final bool highlight;
}

/// Tarjeta destacada del dashboard de Administrador: resumen operativo
/// del dia en una grilla de 2x2.
class AdminSummaryCard extends StatelessWidget {
  const AdminSummaryCard({super.key, required this.stats});

  final List<SummaryStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESUMEN OPERATIVO DEL DÍA',
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final stat in stats) _StatTile(stat: stat),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final SummaryStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 26,
              color: stat.highlight ? AppColors.danger : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              stat.label,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Features/quotes/data/mock_quotes.dart
// ====================================================================

/// Estado de una cotización.
enum QuoteStatus { aprobada, pendiente, rechazada }

extension QuoteStatusView on QuoteStatus {
  String get label => switch (this) {
        QuoteStatus.aprobada => 'Aprobada',
        QuoteStatus.pendiente => 'Pendiente',
        QuoteStatus.rechazada => 'Rechazada',
      };

  StatusTone get tone => switch (this) {
        QuoteStatus.aprobada => StatusTone.success,
        QuoteStatus.pendiente => StatusTone.warning,
        QuoteStatus.rechazada => StatusTone.danger,
      };
}

/// Línea de una cotización.
class QuoteItem {
  const QuoteItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final int quantity;
  final int unitPrice;

  int get subtotal => quantity * unitPrice;
}

/// Cotización de ejemplo (sin backend).
class Quote {
  const Quote({
    required this.code,
    required this.date,
    required this.client,
    required this.productType,
    required this.paymentMethod,
    required this.status,
    required this.items,
  });

  final String code;
  final String date;
  final String client;
  final String productType;
  final String paymentMethod;
  final QuoteStatus status;
  final List<QuoteItem> items;

  int get total =>
      items.fold(0, (sum, item) => sum + item.subtotal);
}

/// Listado mock que alimenta las pantallas de cotizaciones.
const List<Quote> mockQuotes = [
  Quote(
    code: 'COT-2025-001',
    date: '15 jul. 2025',
    client: 'Carlos Ramírez',
    productType: 'Llanta nueva',
    paymentMethod: 'Crédito',
    status: QuoteStatus.aprobada,
    items: [
      QuoteItem(
        description: 'Llanta 205/65R15 Michelin',
        quantity: 4,
        unitPrice: 280000,
      ),
      QuoteItem(
        description: 'Instalación y balanceo',
        quantity: 4,
        unitPrice: 20000,
      ),
    ],
  ),
  Quote(
    code: 'COT-2025-002',
    date: '22 jul. 2025',
    client: 'Transportes del Valle',
    productType: 'Reencauche',
    paymentMethod: 'Contado',
    status: QuoteStatus.pendiente,
    items: [
      QuoteItem(
        description: 'Reencauche 295/80R22.5',
        quantity: 3,
        unitPrice: 150000,
      ),
    ],
  ),
  Quote(
    code: 'COT-2025-003',
    date: '3 ago. 2025',
    client: 'Carlos Ramírez',
    productType: 'Llanta nueva',
    paymentMethod: 'Crédito',
    status: QuoteStatus.rechazada,
    items: [
      QuoteItem(
        description: 'Llanta 225/45R17 Bridgestone',
        quantity: 2,
        unitPrice: 445000,
      ),
    ],
  ),
];

/// Producto del catálogo que se puede agregar a una cotización.
class Product {
  const Product({
    required this.name,
    required this.brand,
    required this.size,
    required this.price,
    required this.retread,
    this.stock = 0,
  });

  final String name;
  final String brand;
  final String size;
  final int price;

  /// `true` si es reencauche; `false` si es llanta nueva.
  final bool retread;
  final int stock;

  String get typeLabel => retread ? 'Reencauche' : 'Llanta nueva';
}

/// Catálogo mock que se muestra al armar una cotización.
const List<Product> mockProducts = [
  Product(
    name: 'Michelin Energy XM2',
    brand: 'Michelin',
    size: '205/65R15',
    price: 280000,
    retread: false,
    stock: 24,
  ),
  Product(
    name: 'Bridgestone Turanza T005',
    brand: 'Bridgestone',
    size: '225/45R17',
    price: 445000,
    retread: false,
    stock: 12,
  ),
  Product(
    name: 'Goodyear EfficientGrip',
    brand: 'Goodyear',
    size: '195/60R15',
    price: 265000,
    retread: false,
    stock: 18,
  ),
  Product(
    name: 'Pirelli Scorpion ATR',
    brand: 'Pirelli',
    size: '265/70R16',
    price: 690000,
    retread: false,
    stock: 6,
  ),
  Product(
    name: 'Reencauche liso de carga',
    brand: 'MiraLlantas',
    size: '295/80R22.5',
    price: 150000,
    retread: true,
    stock: 30,
  ),
  Product(
    name: 'Reencauche mixto tracción',
    brand: 'MiraLlantas',
    size: '11R22.5',
    price: 165000,
    retread: true,
    stock: 15,
  ),
  Product(
    name: 'Reencauche urbano',
    brand: 'MiraLlantas',
    size: '215/75R17.5',
    price: 132000,
    retread: true,
    stock: 21,
  ),
  Product(
    name: 'Instalación y balanceo',
    brand: 'Servicio',
    size: 'Por llanta',
    price: 20000,
    retread: false,
    stock: 99,
  ),
];

// ====================================================================
// Features/credits/data/mock_credits.dart
// ====================================================================

/// Estado de un crédito.
enum CreditStatus { alDia, vencido }

extension CreditStatusView on CreditStatus {
  String get label =>
      this == CreditStatus.alDia ? 'Al día' : 'Vencido';

  StatusTone get tone =>
      this == CreditStatus.alDia ? StatusTone.success : StatusTone.danger;
}

/// Abono registrado sobre un crédito.
class Payment {
  const Payment({
    required this.amount,
    required this.date,
    required this.method,
    this.confirmed = true,
  });

  final int amount;
  final String date;
  final String method;
  final bool confirmed;
}

/// Crédito de ejemplo (sin backend).
class Credit {
  const Credit({
    required this.code,
    required this.status,
    required this.dueDate,
    required this.startDate,
    required this.total,
    required this.paid,
    required this.monthlyFee,
    required this.payments,
  });

  final String code;
  final CreditStatus status;
  final String dueDate;
  final String startDate;
  final int total;
  final int paid;
  final int monthlyFee;
  final List<Payment> payments;

  int get pending => total - paid;

  double get progress => total == 0 ? 0 : paid / total;

  int get progressPercent => (progress * 100).round();
}

/// Listado mock que alimenta las pantallas de créditos y abonos.
const List<Credit> mockCredits = [
  Credit(
    code: 'CRD-2025-001',
    status: CreditStatus.alDia,
    dueDate: '30 sep. 2025',
    startDate: '1 abr. 2025',
    total: 4500000,
    paid: 2100000,
    monthlyFee: 350000,
    payments: [
      Payment(amount: 350000, date: '1 ago. 2025', method: 'Transferencia'),
      Payment(amount: 350000, date: '1 jul. 2025', method: 'Transferencia'),
      Payment(amount: 200000, date: '3 jun. 2025', method: 'Efectivo'),
      Payment(amount: 150000, date: '1 jun. 2025', method: 'Transferencia'),
    ],
  ),
  Credit(
    code: 'CRD-2025-002',
    status: CreditStatus.vencido,
    dueDate: '15 ago. 2025',
    startDate: '15 feb. 2025',
    total: 1800000,
    paid: 1800000,
    monthlyFee: 300000,
    payments: [
      Payment(amount: 300000, date: '15 jul. 2025', method: 'Nequi'),
      Payment(amount: 300000, date: '15 jun. 2025', method: 'Nequi'),
    ],
  ),
];

/// Métodos de pago disponibles al registrar un abono.
const List<String> paymentMethods = [
  'Transferencia',
  'Efectivo',
  'Nequi',
  'Daviplata',
];

// ====================================================================
// Features/deliveries/data/mock_deliveries.dart
// ====================================================================

/// Estado de una entrega.
enum DeliveryStatus { entregado, programado, cancelado }

extension DeliveryStatusView on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.entregado => 'Entregado',
        DeliveryStatus.programado => 'Programado',
        DeliveryStatus.cancelado => 'Cancelado',
      };

  StatusTone get tone => switch (this) {
        DeliveryStatus.entregado => StatusTone.success,
        DeliveryStatus.programado => StatusTone.warning,
        DeliveryStatus.cancelado => StatusTone.danger,
      };
}

/// Entrega de ejemplo (sin backend).
class Delivery {
  const Delivery({
    required this.code,
    required this.address,
    required this.scheduledDate,
    required this.status,
    required this.quoteCode,
    this.deliveredDate,
  });

  final String code;
  final String address;
  final String scheduledDate;
  final DeliveryStatus status;
  final String quoteCode;
  final String? deliveredDate;
}

/// Listado mock que alimenta las pantallas de entregas.
const List<Delivery> mockDeliveries = [
  Delivery(
    code: 'ENT-001',
    address: 'Cra. 45 #80-23, Medellín',
    scheduledDate: '18 jul. 2025',
    deliveredDate: '18 jul. 2025',
    status: DeliveryStatus.entregado,
    quoteCode: 'COT-2025-001',
  ),
  Delivery(
    code: 'ENT-002',
    address: 'Cl. 10 #5-67, El Poblado',
    scheduledDate: '28 ago. 2025',
    status: DeliveryStatus.programado,
    quoteCode: 'COT-2025-002',
  ),
  Delivery(
    code: 'ENT-003',
    address: 'Av. El Dorado #68C-61, Bogotá',
    scheduledDate: '10 ago. 2025',
    status: DeliveryStatus.cancelado,
    quoteCode: 'COT-2025-003',
  ),
];

// ====================================================================
// core/routes/app_routes.dart
// ====================================================================

/// Rutas de la app. Toda la navegacion pasa por [onGenerateRoute].
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/recuperar-contrasena';
  static const String userDashboard = '/dashboard/usuario';
  static const String adminDashboard = '/dashboard/administrador';
  static const String profile = '/perfil';
  static const String editProfile = '/perfil/editar';
  static const String quotes = '/cotizaciones';
  static const String quoteDetail = '/cotizaciones/detalle';
  static const String newQuote = '/cotizaciones/nueva';
  static const String credits = '/creditos';
  static const String creditDetail = '/creditos/detalle';
  static const String newPayment = '/abonos/nuevo';
  static const String paymentsHistory = '/abonos';
  static const String deliveries = '/entregas';
  static const String deliveryDetail = '/entregas/detalle';


  /// Ruta del dashboard que corresponde a cada rol.
  static String dashboardFor(UserRole role) =>
      role == UserRole.administrador ? adminDashboard : userDashboard;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _page(const SplashPage(), settings);
      case login:
        return _page(const LoginPage(), settings);
      case forgotPassword:
        return _page(const ForgotPasswordPage(), settings);
      case userDashboard:
        return _page(const UserDashboardPage(), settings);
      case adminDashboard:
        return _page(const AdminDashboardPage(), settings);
      case profile:
        final role = settings.arguments is UserRole
            ? settings.arguments! as UserRole
            : UserRole.usuario;
        return _page(ProfilePage(role: role), settings);
      case editProfile:
        final role = settings.arguments is UserRole
            ? settings.arguments! as UserRole
            : UserRole.usuario;
        return _page(EditProfilePage(role: role), settings);
      case quotes:
        return _page(const QuotesListPage(), settings);
      case newQuote:
        return _page(const NewQuotePage(), settings);
      case quoteDetail:
        final quote = settings.arguments is Quote
            ? settings.arguments! as Quote
            : mockQuotes.first;
        return _page(QuoteDetailPage(quote: quote), settings);
      case credits:
        return _page(const CreditsListPage(), settings);
      case creditDetail:
        final credit = settings.arguments is Credit
            ? settings.arguments! as Credit
            : mockCredits.first;
        return _page(CreditDetailPage(credit: credit), settings);
      case newPayment:
        return _page(
          NewPaymentPage(credit: settings.arguments as Credit?),
          settings,
        );
      case paymentsHistory:
        return _page(
          PaymentsHistoryPage(credit: settings.arguments as Credit?),
          settings,
        );
      case deliveries:
        return _page(const DeliveriesListPage(), settings);
      case deliveryDetail:
        final delivery = settings.arguments is Delivery
            ? settings.arguments! as Delivery
            : mockDeliveries.first;
        return _page(DeliveryDetailPage(delivery: delivery), settings);
      default:

        return _page(_UnknownRoutePage(name: settings.name), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) {
    return MaterialPageRoute<dynamic>(builder: (_) => child, settings: s);
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pantalla no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No existe una pantalla para la ruta "${name ?? ''}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/splash/presentation/pages/splash_page.dart
// ====================================================================

/// Pantalla de carga inicial. Simula un arranque y pasa al login.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiraLogo(size: 104),
              const SizedBox(height: 24),
              Text('MiraLlantas', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Gestión de llantas y reencauche',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/Auth/presentation/pages/login_page.dart
// ====================================================================

/// Login de MiraLlantas. Solo UI: no valida credenciales, unicamente
/// navega al dashboard del rol seleccionado.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  UserRole _role = UserRole.usuario;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.dashboardFor(_role),
      arguments: _role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Cambiar tema',
                  onPressed: ThemeController.instance.toggle,
                  icon: Icon(
                    palette.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: MiraLogo()),
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
                      const SizedBox(height: 28),
                      CustomTextField(
                        label: 'Correo electrónico',
                        hint: 'correo@ejemplo.com',
                        controller: _email,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      CustomTextField(
                        label: 'Contraseña',
                        hint: '........',
                        controller: _password,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRoutes.forgotPassword),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RoleSelector(
                        value: _role,
                        onChanged: (role) => setState(() => _role = role),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        label: 'Iniciar sesión',
                        onPressed: _signIn,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Features/Auth/presentation/pages/forgot_password_page.dart
// ====================================================================

/// Recuperación de contraseña. Solo UI: muestra un mensaje simulado.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MiraLogo(size: 68)),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Recuperar acceso',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe el correo con el que te registraste y te '
                    'enviaremos las instrucciones para crear una nueva '
                    'contraseña.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Correo electrónico',
                    hint: 'correo@ejemplo.com',
                    controller: _email,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Enviar instrucciones',
                    onPressed: () => setState(() => _sent = true),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Listo. Si el correo existe, recibirás un enlace en '
                      'unos minutos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  CustomButton.outlined(
                    label: 'Volver al inicio de sesión',
                    onPressed: () => Navigator.of(context).pop(),
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

// ====================================================================
// Features/dashboard/presentation/pages/user_dashboard_page.dart
// ====================================================================

/// Dashboard del cliente. Todos los datos son mock: no hay backend.
class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  // Datos de ejemplo del cliente.
  static const String _name = 'Carlos Ramírez';
  static const int _available = 2400000;
  static const int _used = 2100000;
  static const int _total = 4500000;

  void _open(String route, {Object? arguments}) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  void _openProfile() => _open(AppRoutes.profile, arguments: UserRole.usuario);

  void _logout() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final modules = <ModuleItem>[
      ModuleItem(
        label: 'Cotizaciones',
        icon: Icons.description_outlined,
        onTap: () => _open(AppRoutes.quotes),
      ),
      ModuleItem(
        label: 'Créditos',
        icon: Icons.credit_card_outlined,
        onTap: () => _open(AppRoutes.credits),
      ),
      ModuleItem(
        label: 'Abonos',
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => _open(AppRoutes.paymentsHistory),
      ),
      ModuleItem(
        label: 'Entregas',
        icon: Icons.local_shipping_outlined,
        onTap: () => _open(AppRoutes.deliveries),
      ),
      ModuleItem(
        label: 'Mi Perfil',
        icon: Icons.person_outline,
        onTap: _openProfile,
      ),
      ModuleItem(
        label: 'Cerrar sesión',
        icon: Icons.logout,
        standout: true,
        onTap: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const DashboardHeader(name: _name),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const CreditBalanceCard(
                  available: _available,
                  used: _used,
                  total: _total,
                ),
                const SizedBox(height: 24),
                Text('MÓDULOS', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    for (final module in modules) ModuleCard(item: module),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

// ====================================================================
// Features/dashboard/presentation/pages/admin_dashboard_page.dart
// ====================================================================

/// Dashboard del administrador. Misma estructura visual que el del
/// cliente, con resumen operativo en lugar del saldo. Datos mock.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const String _name = 'Laura González';

  static const List<SummaryStat> _stats = [
    SummaryStat(value: '5', label: 'Pedidos pendientes'),
    SummaryStat(value: '3', label: 'Entregas hoy'),
    SummaryStat(value: '2', label: 'Créditos por vencer', highlight: true),
    SummaryStat(value: '1', label: 'Nuevos clientes'),
  ];

  void _openModule(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Módulo "$label" en construcción')),
      );
  }

  void _open(String route, {Object? arguments}) {
    Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  void _openProfile() => _open(AppRoutes.profile, arguments: UserRole.administrador);

  void _logout() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final modules = <ModuleItem>[
      ModuleItem(
        label: 'Cotizaciones',
        icon: Icons.description_outlined,
        onTap: () => _open(AppRoutes.quotes),
      ),
      ModuleItem(
        label: 'Créditos',
        icon: Icons.credit_card_outlined,
        onTap: () => _open(AppRoutes.credits),
      ),
      ModuleItem(
        label: 'Abonos',
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => _open(AppRoutes.paymentsHistory),
      ),
      ModuleItem(
        label: 'Entregas',
        icon: Icons.local_shipping_outlined,
        onTap: () => _open(AppRoutes.deliveries),
      ),
      ModuleItem(
        label: 'Reencauches',
        icon: Icons.autorenew,
        onTap: () => _openModule('Reencauches'),
      ),
      ModuleItem(
        label: 'Mi Perfil',
        icon: Icons.person_outline,
        onTap: _openProfile,
      ),
      ModuleItem(
        label: 'Cerrar sesión',
        icon: Icons.logout,
        standout: true,
        onTap: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const DashboardHeader(name: _name, roleLabel: 'ADMINISTRADOR'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const AdminSummaryCard(stats: _stats),
                const SizedBox(height: 24),
                Text('MÓDULOS', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    for (final module in modules) ModuleCard(item: module),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

// ====================================================================
// Features/quotes/presentation/pages/quotes_list_page.dart
// ====================================================================

/// Listado de cotizaciones. Datos mock, sin backend.
class QuotesListPage extends StatelessWidget {
  const QuotesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Cotizaciones'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${mockQuotes.length} COTIZACIONES',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.newQuote),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Nueva'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final quote in mockQuotes) ...[
                  _QuoteCard(quote: quote),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.quoteDetail, arguments: quote),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.code, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${quote.date} · ${quote.client}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quote.items.length} ${quote.items.length == 1 ? "ítem" : "ítems"}'
                      ' · ${quote.paymentMethod} · ${quote.productType}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    StatusChip(
                      label: quote.status.label,
                      tone: quote.status.tone,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatCop(quote.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  color: palette.isDark
                      ? palette.textPrimary
                      : AppColors.onAccent,
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/quotes/presentation/pages/quote_detail_page.dart
// ====================================================================

/// Detalle de una cotización con sus ítems y el total.
class QuoteDetailPage extends StatelessWidget {
  const QuoteDetailPage({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          MiraHeader(title: quote.code),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quote.date,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          StatusChip(
                            label: quote.status.label,
                            tone: quote.status.tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(label: 'Cliente', value: quote.client),
                      _InfoRow(label: 'Tipo', value: quote.productType),
                      _InfoRow(label: 'Pago', value: quote.paymentMethod),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('ÍTEMS DE LA COTIZACIÓN',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
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
                            child: Text(
                              'CANT.',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'SUBTOTAL',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final item in quote.items) ...[
                        Divider(height: 20, color: palette.border),
                        _ItemRow(item: item),
                      ],
                      Divider(height: 24, color: palette.border),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total',
                                style: theme.textTheme.titleMedium),
                          ),
                          Text(
                            formatCop(quote.total),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: palette.isDark
                                  ? AppColors.info
                                  : palette.header,
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
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final QuoteItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(item.description, style: theme.textTheme.bodyLarge),
        ),
        Expanded(
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCop(item.unitPrice),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                formatCop(item.subtotal),
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Features/quotes/presentation/pages/new_quote_page.dart
// ====================================================================

/// Armado de una cotización: catálogo de productos con buscador, ítems
/// agregados y un único formulario para llanta nueva o reencauche.
/// Solo UI, sin backend.
class NewQuotePage extends StatefulWidget {
  const NewQuotePage({super.key});

  @override
  State<NewQuotePage> createState() => _NewQuotePageState();
}

class _NewQuotePageState extends State<NewQuotePage> {
  final TextEditingController _search = TextEditingController();

  /// Ítems agregados: producto -> cantidad.
  final Map<Product, int> _cart = {};

  int _paymentMethod = 0;
  String _query = '';

  List<Product> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return mockProducts;
    return [
      for (final p in mockProducts)
        if ('${p.name} ${p.brand} ${p.size} ${p.typeLabel}'
            .toLowerCase()
            .contains(q))
          p,
    ];
  }

  int get _total => _cart.entries
      .fold(0, (sum, e) => sum + e.key.price * e.value);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(Product product) {
    setState(() => _cart[product] = (_cart[product] ?? 0) + 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado'),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _remove(Product product) {
    setState(() {
      final next = (_cart[product] ?? 0) - 1;
      if (next <= 0) {
        _cart.remove(product);
      } else {
        _cart[product] = next;
      }
    });
  }

  Future<void> _addCustomProduct() async {
    final result = await showModalBottomSheet<(Product, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProductFormSheet(),
    );
    if (result == null || !mounted) return;
    final (product, quantity) = result;
    setState(() => _cart[product] = (_cart[product] ?? 0) + quantity);
  }

  void _save() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Cotización guardada (demo)')),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final results = _results;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Nueva cotización'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto, marca o medida',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('PRODUCTOS DISPONIBLES',
                          style: theme.textTheme.labelSmall),
                    ),
                    Text('${results.length}',
                        style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No hay productos que coincidan con la búsqueda.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                for (final product in results) ...[
                  _ProductCard(
                    product: product,
                    quantity: _cart[product] ?? 0,
                    onAdd: () => _add(product),
                    onRemove: () => _remove(product),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                CustomButton.outlined(
                  label: 'Agregar producto personalizado',
                  icon: Icons.tune,
                  onPressed: _addCustomProduct,
                ),
                const SizedBox(height: 24),
                Text('PRODUCTOS AGREGADOS',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                _CartSummary(cart: _cart, total: _total),
                const SizedBox(height: 24),
                Text('MÉTODO DE PAGO', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: SelectableTab(
                          label: i == 0 ? 'Crédito' : 'Contado',
                          selected: _paymentMethod == i,
                          onTap: () => setState(() => _paymentMethod = i),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton.outlined(
                        label: 'Cancelar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Guardar cotización',
                        onPressed: _cart.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

/// Tarjeta de producto del catálogo con su botón de agregar.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final selected = quantity > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.accent : palette.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.iconTileBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              product.retread ? Icons.autorenew : Icons.trip_origin,
              color: palette.iconTileFg,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.brand} · ${product.size} · '
                  'stock ${product.stock}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(
                      label: product.typeLabel,
                      tone: StatusTone.neutral,
                    ),
                    Text(
                      formatCop(product.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (selected)
            Row(
              children: [
                IconButton(
                  tooltip: 'Quitar uno',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$quantity', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: 'Agregar otro',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: AppColors.accent),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Agregar'),
            ),
        ],
      ),
    );
  }
}

/// Resumen de los productos agregados a la cotización.
class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart, required this.total});

  final Map<Product, int> cart;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: cart.isEmpty
          ? Text(
              'Todavía no has agregado productos.',
              style: theme.textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final entry in cart.entries) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.value} × ${entry.key.name}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        formatCop(entry.key.price * entry.value),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                  Divider(height: 18, color: palette.border),
                ],
                Row(
                  children: [
                    Expanded(
                      child:
                          Text('Total', style: theme.textTheme.titleMedium),
                    ),
                    Text(
                      formatCop(total),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.isDark
                            ? AppColors.info
                            : palette.header,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Pestaña seleccionable reutilizada por el método de pago y por el tipo
/// de producto del formulario.
class SelectableTab extends StatelessWidget {
  const SelectableTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color fg = selected ? palette.textPrimary : palette.textSecondary;

    return Material(
      color: selected ? palette.surfaceAlt : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.header : palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
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

/// Formulario único para llanta nueva y reencauche: solo cambia el tipo
/// seleccionado, los campos son los mismos. Devuelve el producto y la
/// cantidad a agregar.
class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet();

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _width = TextEditingController();
  final TextEditingController _profile = TextEditingController();
  final TextEditingController _rim = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _price = TextEditingController();

  bool _retread = false;

  @override
  void dispose() {
    _brand.dispose();
    _width.dispose();
    _profile.dispose();
    _rim.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _brand.text.trim().isEmpty
        ? (_retread ? 'Reencauche personalizado' : 'Llanta personalizada')
        : _brand.text.trim();
    final size = [
      _width.text.trim(),
      _profile.text.trim(),
      _rim.text.trim(),
    ].where((v) => v.isNotEmpty).join('/');

    final product = Product(
      name: name,
      brand: 'Personalizado',
      size: size.isEmpty ? 'Sin medida' : size,
      price: int.tryParse(_price.text.trim()) ?? 0,
      retread: _retread,
    );
    final quantity = int.tryParse(_quantity.text.trim()) ?? 1;
    Navigator.of(context).pop((product, quantity < 1 ? 1 : quantity));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
          ),
          border: Border.all(color: palette.border),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Producto personalizado',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Los mismos campos sirven para llanta nueva y reencauche.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SelectableTab(
                      label: 'Llanta nueva',
                      icon: Icons.trip_origin,
                      selected: !_retread,
                      onTap: () => setState(() => _retread = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableTab(
                      label: 'Reencauche',
                      icon: Icons.autorenew,
                      selected: _retread,
                      onTap: () => setState(() => _retread = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              CustomTextField(
                label: 'Marca / Modelo',
                hint: 'Michelin Energy XM2',
                controller: _brand,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Ancho (mm)',
                      hint: '205',
                      controller: _width,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Perfil (%)',
                      hint: '65',
                      controller: _profile,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Rin (pulg)',
                      hint: '15',
                      controller: _rim,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Cantidad',
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      label: 'Valor unitario (COP)',
                      hint: '280000',
                      controller: _price,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: CustomButton.outlined(
                      label: 'Cancelar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: 'Agregar',
                      onPressed: _submit,
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

// ====================================================================
// Features/credits/presentation/pages/credits_list_page.dart
// ====================================================================

/// Listado de créditos del cliente. Datos mock, sin backend.
class CreditsListPage extends StatelessWidget {
  const CreditsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Mis créditos'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text('${mockCredits.length} CRÉDITOS',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                for (final credit in mockCredits) ...[
                  _CreditCard(credit: credit),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credit});

  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final bool overdue = credit.status == CreditStatus.vencido;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.creditDetail, arguments: credit),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(credit.code,
                        style: theme.textTheme.titleMedium),
                  ),
                  StatusChip(
                    label: credit.status.label,
                    tone: credit.status.tone,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Vence: ${credit.dueDate}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: 'Pendiente: '),
                          TextSpan(
                            text: formatCop(credit.pending),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text('Total: ${formatCop(credit.total)}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: credit.progress,
                  minHeight: 7,
                  backgroundColor: palette.trackBg,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overdue ? AppColors.danger : palette.header,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${credit.progressPercent}% abonado · Cuota: '
                '${formatCop(credit.monthlyFee)} / mes',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/credits/presentation/pages/credit_detail_page.dart
// ====================================================================

/// Detalle de un crédito: saldo, avance y accesos a abonos.
class CreditDetailPage extends StatelessWidget {
  const CreditDetailPage({super.key, required this.credit});

  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          MiraHeader(title: credit.code),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Saldo pendiente',
                                style: theme.textTheme.bodyMedium),
                          ),
                          StatusChip(
                            label: credit.status.label,
                            tone: credit.status.tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(formatCop(credit.pending),
                          style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: credit.progress,
                          minHeight: 8,
                          backgroundColor: palette.trackBg,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _Fact(
                              label: 'Valor total',
                              value: formatCop(credit.total),
                            ),
                          ),
                          Expanded(
                            child: _Fact(
                              label: 'Abonado',
                              value: formatCop(credit.paid),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Fact(
                              label: 'Cuota mensual',
                              value:
                                  '${formatCop(credit.monthlyFee)} / mes',
                            ),
                          ),
                          Expanded(
                            child: _Fact(
                              label: 'Inicio',
                              value: credit.startDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Fact(
                              label: 'Vence',
                              value: credit.dueDate,
                            ),
                          ),
                          Expanded(
                            child: _Fact(
                              label: 'Progreso',
                              value: '${credit.progressPercent}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Registrar abono',
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRoutes.newPayment,
                          arguments: credit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton.outlined(
                        label: 'Ver historial',
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRoutes.paymentsHistory,
                          arguments: credit,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

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

// ====================================================================
// Features/credits/presentation/pages/new_payment_page.dart
// ====================================================================

/// Registro de un abono. Solo UI: no sube archivos ni guarda nada.
class NewPaymentPage extends StatefulWidget {
  const NewPaymentPage({super.key, this.credit});

  final Credit? credit;

  @override
  State<NewPaymentPage> createState() => _NewPaymentPageState();
}

class _NewPaymentPageState extends State<NewPaymentPage> {
  final TextEditingController _amount = TextEditingController();
  int _method = 0;
  bool _hasReceipt = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Abono registrado (demo)')),
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
          const MiraHeader(title: 'Registrar abono'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                CustomTextField(
                  label: 'Monto del abono (COP)',
                  hint: '350000',
                  controller: _amount,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                Text('Método de pago', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < paymentMethods.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _MethodTab(
                          label: paymentMethods[i],
                          selected: i == _method,
                          onTap: () => setState(() => _method = i),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text('Comprobante de pago',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _ReceiptDropZone(
                  attached: _hasReceipt,
                  onTap: () => setState(() => _hasReceipt = !_hasReceipt),
                ),
                const SizedBox(height: 24),
                CustomButton(label: 'Guardar abono', onPressed: _save),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
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
          padding: const EdgeInsets.symmetric(horizontal: 6),
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

/// Zona punteada para adjuntar el comprobante (simulada).
class _ReceiptDropZone extends StatelessWidget {
  const _ReceiptDropZone({required this.attached, required this.onTap});

  final bool attached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              attached ? Icons.check_circle_outline : Icons.upload_outlined,
              color: palette.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              attached ? 'comprobante.jpg' : 'Subir comprobante',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro con borde discontinuo dibujado a mano.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CustomPaint(
      foregroundPainter: _DashedRectPainter(color: palette.border),
      child: Container(
        height: 118,
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ====================================================================
// Features/credits/presentation/pages/payments_history_page.dart
// ====================================================================

/// Historial de abonos de un crédito (o de todos si no se pasa uno).
class PaymentsHistoryPage extends StatelessWidget {
  const PaymentsHistoryPage({super.key, this.credit});

  final Credit? credit;

  List<Payment> get _payments =>
      credit?.payments ??
      [for (final c in mockCredits) ...c.payments];

  int get _total =>
      _payments.fold(0, (sum, payment) => sum + payment.amount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          MiraHeader(
            title: credit == null ? 'Abonos' : 'Historial de abonos',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.header,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total abonado',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.onHeaderMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatCop(_total),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: palette.onHeader,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_payments.length} transacciones',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.onHeaderMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('TRANSACCIONES', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                for (final payment in _payments) ...[
                  _PaymentTile(payment: payment),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatCop(payment.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                    )),
                const SizedBox(height: 4),
                Text('${payment.date} · ${payment.method}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          StatusChip(
            label: payment.confirmed ? 'Confirmado' : 'Pendiente',
            tone: payment.confirmed
                ? StatusTone.success
                : StatusTone.warning,
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Features/deliveries/presentation/pages/deliveries_list_page.dart
// ====================================================================

/// Listado de entregas. Datos mock, sin backend.
class DeliveriesListPage extends StatelessWidget {
  const DeliveriesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Entregas'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text('${mockDeliveries.length} ENTREGAS',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                for (final delivery in mockDeliveries) ...[
                  _DeliveryCard(delivery: delivery),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed(AppRoutes.deliveryDetail, arguments: delivery),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.code,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${delivery.address} · ${delivery.scheduledDate}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    StatusChip(
                      label: delivery.status.label,
                      tone: delivery.status.tone,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Features/deliveries/presentation/pages/delivery_detail_page.dart
// ====================================================================

/// Detalle de una entrega con su evidencia fotográfica.
class DeliveryDetailPage extends StatelessWidget {
  const DeliveryDetailPage({super.key, required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          MiraHeader(title: delivery.code),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Estado de entrega',
                                style: theme.textTheme.titleMedium),
                          ),
                          StatusChip(
                            label: delivery.status.label,
                            tone: delivery.status.tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DeliveryInfoRow(
                        label: 'Cotización',
                        value: delivery.quoteCode,
                      ),
                      _DeliveryInfoRow(
                        label: 'Dirección',
                        value: delivery.address,
                      ),
                      _DeliveryInfoRow(
                        label: 'Fecha programada',
                        value: delivery.scheduledDate,
                      ),
                      _DeliveryInfoRow(
                        label: 'Fecha de entrega',
                        value: delivery.deliveredDate ?? 'Sin entregar',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('EVIDENCIA FOTOGRÁFICA',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Container(
                  height: 190,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 34,
                        color: palette.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        delivery.status == DeliveryStatus.entregado
                            ? 'Foto de entrega disponible'
                            : 'Sin evidencia registrada',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  const _DeliveryInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Features/profile/presentation/pages/profile_page.dart
// ====================================================================

/// Perfil del usuario en sesión. Datos de ejemplo, sin backend.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.role = UserRole.usuario});

  final UserRole role;

  bool get _isAdmin => role == UserRole.administrador;

  String get _name => _isAdmin ? 'Laura González' : 'Carlos Ramírez';
  String get _email =>
      _isAdmin ? 'laura.gonzalez@mirallantas.com' : 'carlos.ramirez@email.com';

  List<_ProfileField> get _fields => [
        _ProfileField('Nombre completo', _name),
        _ProfileField('Documento', _isAdmin ? '43876521' : '1023456789'),
        _ProfileField('Correo', _email),
        _ProfileField('Teléfono', _isAdmin ? '301 987 6543' : '300 456 7890'),
        _ProfileField(
          'Dirección',
          _isAdmin
              ? 'Cl. 10 #43-15, Medellín, Antioquia'
              : 'Cra. 45 #80-23, Medellín, Antioquia',
        ),
        _ProfileField('Rol', role.label),
      ];

  String get _initials {
    final parts = _name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Mi perfil'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: palette.header,
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: palette.onHeader,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(_name, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(_email, style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(height: 28),
                Text('INFORMACIÓN PERSONAL',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _fields.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: palette.border),
                        _ProfileRow(field: _fields[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                CustomButton(
                  label: 'Editar perfil',
                  icon: Icons.edit_outlined,
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.editProfile, arguments: role),
                ),
                const SizedBox(height: 12),
                CustomButton.outlined(
                  label: 'Cerrar sesión',
                  icon: Icons.logout,
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                          AppRoutes.login, (route) => false),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

class _ProfileField {
  const _ProfileField(this.label, this.value);

  final String label;
  final String value;
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.field});

  final _ProfileField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(field.value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Edición de los datos del usuario. Solo UI: al guardar muestra un
/// aviso y vuelve al perfil.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.role = UserRole.usuario});

  final UserRole role;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final bool _isAdmin = widget.role == UserRole.administrador;

  late final TextEditingController _name = TextEditingController(
    text: _isAdmin ? 'Laura González' : 'Carlos Ramírez',
  );
  late final TextEditingController _document = TextEditingController(
    text: _isAdmin ? '43876521' : '1023456789',
  );
  late final TextEditingController _email = TextEditingController(
    text: _isAdmin
        ? 'laura.gonzalez@mirallantas.com'
        : 'carlos.ramirez@email.com',
  );
  late final TextEditingController _phone = TextEditingController(
    text: _isAdmin ? '301 987 6543' : '300 456 7890',
  );
  late final TextEditingController _address = TextEditingController(
    text: _isAdmin
        ? 'Cl. 10 #43-15, Medellín, Antioquia'
        : 'Cra. 45 #80-23, Medellín, Antioquia',
  );

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Perfil actualizado (demo)')),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const MiraHeader(title: 'Editar perfil'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                CustomTextField(label: 'Nombre completo', controller: _name),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Documento',
                  controller: _document,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Correo',
                  controller: _email,
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Teléfono',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(label: 'Dirección', controller: _address),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton.outlined(
                        label: 'Cancelar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Guardar cambios',
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiraTabBar(),
    );
  }
}

