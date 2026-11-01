import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cluster_config.dart';
import '../models/cluster_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/cluster_provider.dart';
import '../widgets/nav_drawer.dart';

/// Which dimensions clustering uses and how much each counts, plus group
/// count. Changes apply to this device right away; the
/// banner resets to or publishes the team default.
class DimensionsScreen extends StatefulWidget {
  const DimensionsScreen({super.key});

  @override
  State<DimensionsScreen> createState() => _DimensionsScreenState();
}

class _DimensionsScreenState extends State<DimensionsScreen> {
  String _filter = '';
  static final Set<String> _open = {};
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.ensureClusters();
    });
  }

  ClusterProvider get _clusters => context.read<ClusterProvider>();

  void _update(ClusterConfig Function(ClusterConfig c) change) =>
      _clusters.setCustom(change(_clusters.resolvedConfig));

  void _toggle(ClusterResult r, String feature, bool on) => _update((c) {
        final selected = {...c.features};
        on ? selected.add(feature) : selected.remove(feature);
        // Keep the API's variance ordering.
        return c.copyWith(features: [
          for (final f in r.availableFeatures)
            if (selected.contains(f.name)) f.name,
        ]);
      });

  Future<void> _refresh() async {
    await _clusters.reloadTeamDefault();
    await _clusters.fetch(refresh: true);
  }

  Future<void> _publish(ClusterConfig c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish as team default?'),
        content: Text(
          'Everyone following the team default will cluster with these '
          '${c.features.length} dimensions and ${c.k} groups. '
          'People with their own custom settings keep them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = context.read<AppStateProvider>().settings.scouterName;
    setState(() => _publishing = true);
    try {
      await _clusters.publishAsTeamDefault(name);
      messenger.showSnackBar(const SnackBar(content: Text('Published as the team default')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _publishing = false);
  }

  Widget _banner(ClusterProvider p) {
    final theme = Theme.of(context);
    final def = p.teamDefault;
    final (title, detail) = switch ((p.isCustom, def)) {
      (true, null) => ('Custom', 'Only on this device. No team default has been published.'),
      (true, _) => ('Custom', 'Only on this device; differs from the team default.'),
      (false, null) => ('Built-in defaults', 'No team default has been published yet.'),
      (false, final d?) => (
          'Team default',
          [
            'Published',
            if ((d.updatedBy ?? '').isNotEmpty) 'by ${d.updatedBy}',
            if (d.updatedAt != null) _date(d.updatedAt!.toLocal()),
          ].join(' '),
        ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: p.isCustom ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Text(detail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p.isCustom)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo),
                    label: Text(def == null ? 'Reset to built-in' : 'Reset to team default'),
                    onPressed: p.resetToTeamDefault,
                  ),
                if (p.isCustom || def == null)
                  FilledButton.tonalIcon(
                    icon: _publishing
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish),
                    label: const Text('Publish as team default'),
                    onPressed: _publishing || p.result == null ? null : () => _publish(p.resolvedConfig),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _settings(ClusterConfig c) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Groups', style: theme.textTheme.labelLarge),
              IconButton(
                tooltip: 'Fewer groups',
                icon: const Icon(Icons.remove),
                onPressed: c.k > ClusterConfig.minK ? () => _update((c) => c.copyWith(k: c.k - 1)) : null,
              ),
              Text('${c.k}', style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'More groups',
                icon: const Icon(Icons.add),
                onPressed: c.k < ClusterConfig.maxK ? () => _update((c) => c.copyWith(k: c.k + 1)) : null,
              ),
            ],
          ),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter dimensions',
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
        ],
      ),
    );
  }

  static String _phase(ClusterFeature f) {
    final n = f.name.toLowerCase();
    if (n.contains('auto')) return 'Auto';
    if (n.contains('teleop')) return 'Teleop';
    if (n.contains('endgame') || n.contains('tower')) return 'Endgame';
    return 'Other';
  }

  /// One collapsible phase group. Collapsed by default (remembered for the
  /// session); a filter opens every group with a match.
  Widget _group(String id, String phase, List<ClusterFeature> feats, ClusterResult r, ClusterConfig c) {
    final theme = Theme.of(context);
    final open = _filter.isNotEmpty || _open.contains(id);
    final on = feats.where((f) => c.features.contains(f.name)).length;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _filter.isNotEmpty
                ? null
                : () => setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(children: [
                Expanded(child: Text(phase, style: theme.textTheme.titleSmall)),
                Text('$on of ${feats.length} on',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.expand_more)),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: open
                ? Column(children: [
                    for (final f in feats)
                      _FeatureRow(
                        feature: f,
                        selected: c.features.contains(f.name),
                        weight: c.weightOf(f.name),
                        onToggle: (on) => _toggle(r, f.name, on),
                        onWeight: (w) => _update((c) => c.copyWith(weights: {...c.weights, f.name: w})),
                      ),
                  ])
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, ClusterResult r, ClusterConfig c, Iterable<ClusterFeature> feats) {
    final theme = Theme.of(context);
    final shown = [
      for (final f in feats)
        if (_filter.isEmpty || f.label.toLowerCase().contains(_filter) || f.name.toLowerCase().contains(_filter)) f,
    ];
    if (shown.isEmpty) return const [];
    final selected = shown.where((f) => c.features.contains(f.name)).length;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text('$title  ·  $selected of ${shown.length} on', style: theme.textTheme.titleMedium),
      ),
      for (final phase in const ['Auto', 'Teleop', 'Endgame', 'Other'])
        if (shown.any((f) => _phase(f) == phase))
          _group('$title $phase', phase, [
            for (final f in shown)
              if (_phase(f) == phase) f,
          ], r, c),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ClusterProvider>();
    final r = p.result;
    final c = p.resolvedConfig;

    Widget message(String text, {bool error = false}) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: error ? TextStyle(color: Theme.of(context).colorScheme.error) : null),
        );

    final body = ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (!p.configured)
          message('Set a secret team key and event in Settings.')
        else ...[
          _banner(p),
          _settings(c),
          if (p.error != null) message(p.error!, error: true),
          if (r == null && p.error == null)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
          if (r != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${c.features.length} dimensions on. Weight multiplies how much a dimension '
                'counts when measuring how alike two teams are. σ is how spread out teams are.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            ..._section('Scouted', r, c, r.availableFeatures.where((f) => !f.isOpr)),
            if (r.hasOpr) ..._section('OPR', r, c, r.availableFeatures.where((f) => f.isOpr)),
          ],
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        // Opened from Clusters: back returns there.
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('Dimensions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: p.configured ? _refresh : null,
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 9),
      body: Column(
        children: [
          if (p.loading) const LinearProgressIndicator(),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

class _FeatureRow extends StatelessWidget {
  final ClusterFeature feature;
  final bool selected;
  final double weight;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onWeight;

  const _FeatureRow({
    required this.feature,
    required this.selected,
    required this.weight,
    required this.onToggle,
    required this.onWeight,
  });

  static String _w(double w) => '${w == w.roundToDouble() ? w.toStringAsFixed(0) : w}×';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sd = math.sqrt(feature.variance);
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: (v) => onToggle(v ?? false),
      title: Text(feature.label),
      subtitle: Text(
        'σ ${sd.toStringAsFixed(sd < 10 ? 2 : 1)}${feature.isDefault ? '' : '  ·  off by default'}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      secondary: selected
          ? DropdownButton<double>(
              value: ClusterConfig.weightSteps.contains(weight) ? weight : 1.0,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final w in ClusterConfig.weightSteps) DropdownMenuItem(value: w, child: Text(_w(w))),
              ],
              onChanged: (w) => onWeight(w ?? 1.0),
            )
          : null,
    );
  }
}
