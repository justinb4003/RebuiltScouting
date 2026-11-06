import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/fixed_segmented_button.dart';
import '../widgets/nav_drawer.dart';

/// Look and feel: light/dark, style, color, font, confetti. Kept apart from
/// Settings so the scouting setup there stays uncluttered.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _confettiKey = GlobalKey<ConfettiOverlayState>();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;
    final theme = Theme.of(context);
    final style = settings.themeStyle;
    final alwaysDark = AppTheme.alwaysDark(style);
    final fixedColors = AppTheme.fixedColors(style);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      drawer: const NavDrawer(selectedIndex: 6),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _sectionHeader('Light or dark'),
                  FixedSegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.settings_brightness)),
                      ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: alwaysDark
                        ? null
                        : (selected) {
                            settings.themeMode = selected.first;
                            appState.saveAndNotify();
                          },
                  ),
                  if (alwaysDark)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text('This style is always dark.', style: note),
                    ),

                  _sectionHeader('Style'),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: RadioGroup<String>(
                      groupValue: style,
                      onChanged: (value) {
                        if (value == null) return;
                        settings.themeStyle = value;
                        appState.saveAndNotify();
                      },
                      child: Column(
                        children: [
                          for (final s in AppTheme.styles)
                            RadioListTile<String>(
                              value: s.id,
                              title: Text(s.label),
                              subtitle: Text(s.description),
                            ),
                        ],
                      ),
                    ),
                  ),

                  _sectionHeader('Color'),
                  _buildColorPicker(appState, settings, enabled: !fixedColors),
                  if (fixedColors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text('This style has its own colors.', style: note),
                    ),

                  _sectionHeader('More'),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Dyslexia-friendly font'),
                          subtitle: const Text('Use OpenDyslexic across the app'),
                          secondary: const Icon(Icons.font_download),
                          value: settings.useOpenDyslexic,
                          onChanged: (value) {
                            settings.useOpenDyslexic = value;
                            appState.saveAndNotify();
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Confetti'),
                          subtitle: const Text('Celebrate when scouting'),
                          secondary: const Icon(Icons.celebration),
                          value: settings.confettiEnabled,
                          onChanged: (value) {
                            settings.confettiEnabled = value;
                            appState.saveAndNotify();
                            if (value) _confettiKey.currentState?.fire();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConfettiOverlay(key: _confettiKey),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker(AppStateProvider appState, AppSettings settings, {required bool enabled}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AppTheme.themeColors.entries.map((entry) {
          final isSelected = settings.themeColor == entry.value.toARGB32();
          return Semantics(
            button: true,
            enabled: enabled,
            label: '${entry.key} theme color${isSelected ? ', selected' : ''}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled
                  ? () {
                      settings.themeColor = entry.value.toARGB32();
                      appState.saveAndNotify();
                    }
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: onSurface, width: 3) : null,
                ),
                child: isSelected
                    ? Icon(Icons.check,
                        color: ThemeData.estimateBrightnessForColor(entry.value) == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        size: 18)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
