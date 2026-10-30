import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/facebook_auth_service.dart';
import '../widgets/app_dialog.dart';
import 'facebook_browser_screen.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 300) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.settings,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _SectionTitle(
              icon: LucideIcons.palette,
              title: l10n.appearance,
              color: scheme.primary,
            ),
            const SizedBox(height: 8),
            _CardContainer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.theme,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ThemeOptionCard(
                          icon: LucideIcons.sun,
                          label: l10n.themeLight,
                          selected: settings.themeMode == ThemeMode.light,
                          onTap: () => settings.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOptionCard(
                          icon: LucideIcons.moon,
                          label: l10n.themeDark,
                          selected: settings.themeMode == ThemeMode.dark,
                          onTap: () => settings.setThemeMode(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOptionCard(
                          icon: LucideIcons.smartphone,
                          label: l10n.themeSystem,
                          selected: settings.themeMode == ThemeMode.system,
                          onTap: () => settings.setThemeMode(ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              icon: LucideIcons.playCircle,
              title: l10n.playerSettings,
              color: scheme.primary,
            ),
            const SizedBox(height: 8),
            _CardContainer(
              child: Column(
                children: [
                  _SettingsDropdownTile(
                    icon: LucideIcons.scanLine,
                    title: l10n.defaultFitMode,
                    value: _fitLabel(settings.defaultFit, l10n),
                    onTap: () => _showFitPicker(context, settings, l10n),
                  ),
                  _Divider(),
                  _SettingsDropdownTile(
                    icon: LucideIcons.gauge,
                    title: l10n.defaultSpeed,
                    value: '${settings.defaultSpeed}×',
                    onTap: () => _showSpeedPicker(context, settings, l10n),
                  ),
                  _Divider(),
                  _SettingsDropdownTile(
                    icon: LucideIcons.fastForward,
                    title: l10n.seekInterval,
                    value: '${settings.seekInterval} seconds',
                    onTap: () => _showSeekPicker(context, settings, l10n),
                  ),
                  _Divider(),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.history, size: 20),
                    title: Text(
                      l10n.autoResume,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      l10n.autoResumeDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.autoResume,
                    activeColor: scheme.primary,
                    onChanged: (v) => settings.setAutoResume(v),
                  ),
                  _Divider(),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.rotateCw, size: 20),
                    title: Text(
                      l10n.autoRotate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      l10n.autoRotateDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.autoRotate,
                    activeColor: scheme.primary,
                    onChanged: (v) => settings.setAutoRotate(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              icon: LucideIcons.globe,
              title: 'Facebook & Browser',
              color: scheme.primary,
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: FacebookAuthService.instance,
              builder: (context, _) {
                final auth = FacebookAuthService.instance;
                final hasSession = auth.hasSession;
                return _CardContainer(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: hasSession
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasSession
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.userX,
                                color: hasSession
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasSession
                                        ? 'Account Connected'
                                        : 'Not Connected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hasSession
                                        ? 'User ID: ${auth.userId.isNotEmpty ? auth.userId : "Active Session"} • fb_dtsg: ${auth.dtsgSummary}'
                                        : 'Log in via browser to extract videos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: auth.hasValidDtsg ? scheme.primary : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Divider(),
                      _AnimatedPressable(
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const FacebookBrowserScreen(),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: const Icon(LucideIcons.compass, size: 20),
                          title: Text(
                            hasSession ? 'Open Facebook Browser' : 'Log In with Facebook',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Browse Facebook to capture login session & cookies',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        ),
                      ),
                      _Divider(),
                      _AnimatedPressable(
                        onTap: () async {
                          final cookies = await FacebookAuthService.instance.fetchAndSyncNativeCookies();
                          if (context.mounted) {
                            final hasXs = cookies.contains('xs=');
                            final hasCuser = cookies.contains('c_user=');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  hasXs && hasCuser
                                      ? 'Cookies synced successfully (xs & c_user found)'
                                      : 'Cookies synced (${cookies.length} chars). ${hasXs ? "" : "Note: xs token not found yet, try browsing Facebook."}',
                                ),
                                backgroundColor: hasXs ? scheme.primary : scheme.secondary,
                              ),
                            );
                          }
                        },
                        child: ListTile(
                          leading: const Icon(LucideIcons.refreshCw, size: 20),
                          title: Text(
                            'Sync Cookies from Browser',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            auth.cookie.contains('xs=')
                                ? 'Full session active (including xs & c_user)'
                                : 'Sync HttpOnly cookies (xs, c_user, datr)',
                            style: TextStyle(
                              fontSize: 12,
                              color: auth.cookie.contains('xs=')
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        ),
                      ),
                      _Divider(),
                      _AnimatedPressable(
                        onTap: () => _showCookieEditor(context, auth),
                        child: ListTile(
                          leading: const Icon(LucideIcons.keyRound, size: 20),
                          title: Text(
                            'Manual Session / Cookie Editor',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'View or paste raw Facebook Cookie and fb_dtsg',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        ),
                      ),
                      if (hasSession) ...[
                        _Divider(),
                        _AnimatedPressable(
                          onTap: () async {
                            final confirm = await AppDialog.showConfirmation(
                              context,
                              icon: LucideIcons.logOut,
                              isDestructive: true,
                              title: 'Clear Session',
                              message:
                                  'Are you sure you want to log out and remove saved Facebook cookies?',
                              cancelLabel: 'Cancel',
                              confirmLabel: 'Log Out',
                            );
                            if (confirm == true) {
                              await FacebookAuthService.instance.clearSession();
                            }
                          },
                          child: ListTile(
                            leading: Icon(LucideIcons.logOut, size: 20, color: scheme.error),
                            title: Text(
                              'Log Out / Clear Session',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.error,
                              ),
                            ),
                            subtitle: Text(
                              'Delete stored cookies and user credentials',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  String _fitLabel(String fit, AppLocalizations l10n) {
    switch (fit) {
      case 'cover':
        return l10n.aspectCover;
      case 'stretch':
        return l10n.aspectStretch;
      case 'r169':
        return l10n.aspect169;
      case 'r43':
        return l10n.aspect43;
      case 'contain':
      default:
        return l10n.aspectContain;
    }
  }
  void _showFitPicker(BuildContext context, SettingsProvider settings, AppLocalizations l10n) {
    final fits = [
      ('contain', l10n.aspectContain),
      ('cover', l10n.aspectCover),
      ('stretch', l10n.aspectStretch),
      ('r169', l10n.aspect169),
      ('r43', l10n.aspect43),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.defaultFitMode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...fits.map((f) {
                final isSel = settings.defaultFit == f.$1;
                return ListTile(
                  title: Text(f.$2,
                      style: TextStyle(
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                        color: isSel ? scheme.primary : scheme.onSurface,
                      )),
                  trailing: isSel ? Icon(LucideIcons.check, color: scheme.primary) : null,
                  onTap: () {
                    settings.setDefaultFit(f.$1);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
  void _showSpeedPicker(BuildContext context, SettingsProvider settings, AppLocalizations l10n) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.defaultSpeed,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: speeds.map((s) {
                  final isSel = settings.defaultSpeed == s;
                  return ChoiceChip(
                    label: Text('${s}×'),
                    selected: isSel,
                    onSelected: (_) {
                      settings.setDefaultSpeed(s);
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
  void _showSeekPicker(BuildContext context, SettingsProvider settings, AppLocalizations l10n) {
    const intervals = [5, 10, 15, 30];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.seekInterval,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...intervals.map((sec) {
                final isSel = settings.seekInterval == sec;
                return ListTile(
                  title: Text('$sec seconds',
                      style: TextStyle(
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                        color: isSel ? scheme.primary : scheme.onSurface,
                      )),
                  trailing: isSel ? Icon(LucideIcons.check, color: scheme.primary) : null,
                  onTap: () {
                    settings.setSeekInterval(sec);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
  void _showCookieEditor(BuildContext context, FacebookAuthService auth) {
    final cookieCtrl = TextEditingController(text: auth.cookie);
    final dtsgCtrl = TextEditingController(text: auth.fbDtsg);
    final userCtrl = TextEditingController(text: auth.userId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(LucideIcons.keyRound, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Session & Cookies Editor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cookieCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Cookie (datr, sb, c_user, xs, ...)',
                    hintText: 'datr=...; c_user=...; xs=...;',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dtsgCtrl,
                  decoration: InputDecoration(
                    labelText: 'fb_dtsg (optional)',
                    hintText: 'NAfx...',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                    labelText: 'User ID (c_user)',
                    hintText: '100011138142072',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final cookie = cookieCtrl.text.trim();
                          final dtsg = dtsgCtrl.text.trim();
                          final uid = userCtrl.text.trim();
                          if (cookie.isNotEmpty) {
                            await FacebookAuthService.instance.overwriteSession(
                              cookie: cookie,
                              fbDtsg: dtsg.isNotEmpty ? dtsg : null,
                              userId: uid.isNotEmpty ? uid : null,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session saved successfully')),
                              );
                            }
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const _AnimatedPressable({
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : scheme.outlineVariant.withOpacity(0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.22)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOptionCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: _AnimatedPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withOpacity(0.14)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _SettingsDropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _AnimatedPressable(
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
    );
  }
}
