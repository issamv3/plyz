import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
class AppDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  const AppDialog({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.content,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(22, 22, 22, 18),
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: scheme.outlineVariant.withOpacity(0.25),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: 345,
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(child: icon!),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: icon != null ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: icon != null ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: 16),
                content!,
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: actions!
                      .map((action) => Expanded(child: action))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  static Future<bool?> showConfirmation(
    BuildContext context, {
    IconData? icon = LucideIcons.alertTriangle,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effIconColor = iconColor ?? (isDestructive ? scheme.error : scheme.primary);
    final effIconBg = iconBgColor ??
        (isDestructive
            ? scheme.errorContainer.withOpacity(0.4)
            : scheme.primaryContainer.withOpacity(0.5));
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon != null
            ? Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: effIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: effIconColor,
                    size: 24,
                  ),
                ),
              )
            : null,
        title: title,
        message: message,
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: scheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelLabel,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? scheme.error : scheme.primary,
              foregroundColor: isDestructive ? scheme.onError : scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  static Future<String?> showInput(
    BuildContext context, {
    IconData? icon = LucideIcons.pencilLine,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    String? message,
    required String initialValue,
    String? hintText,
    required String cancelLabel,
    required String confirmLabel,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effIconColor = iconColor ?? scheme.primary;
    final effIconBg = iconBgColor ?? scheme.primaryContainer.withOpacity(0.5);
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon != null
            ? Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: effIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: effIconColor,
                    size: 24,
                  ),
                ),
              )
            : null,
        title: title,
        message: message,
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 15,
          ),
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            fillColor: scheme.surfaceContainerHighest.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: scheme.primary,
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: scheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              cancelLabel,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  static Future<void> showMessage(
    BuildContext context, {
    IconData? icon = LucideIcons.info,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    required String message,
    required String buttonLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effIconColor = iconColor ?? scheme.primary;
    final effIconBg = iconBgColor ?? scheme.primaryContainer.withOpacity(0.5);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon != null
            ? Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: effIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: effIconColor,
                    size: 24,
                  ),
                ),
              )
            : null,
        title: title,
        message: message,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
