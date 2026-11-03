import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebuilt_scouting/widgets/flip_list.dart';

/// Mirrors the Pick List board: a dropdown filter above rows in a FlipScope,
/// inside a LayoutBuilder and a scroll view.
class _Board extends StatefulWidget {
  const _Board();
  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  int min = 1;

  @override
  Widget build(BuildContext context) {
    // 1 shows all 12; 3 shows 6–12; 10 shows none.
    final rows = [for (var t = 1; t <= 12; t++) if (min == 1 || t >= min + 3) t];
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: FlipScope(
          child: Column(children: [
            DropdownButton<int>(
              value: min,
              items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (v) => setState(() => min = v!),
            ),
            for (final t in rows)
              FlipItem(key: ValueKey(t), child: SizedBox(height: 40, child: Text('Team $t'))),
          ]),
        ),
      ),
    );
  }
}

void main() {
  for (final target in [3, 10]) { // 10 filters every row out
    testWidgets('picking $target in the dropdown drops rows cleanly', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Board())));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$target').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Team 1'), findsNothing);
      if (target == 10) expect(find.textContaining('Team '), findsNothing);
      // And back.
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Team 1'), findsOneWidget);
    });
  }
}
