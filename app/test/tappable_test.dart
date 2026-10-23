import 'package:dalil_app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tappable can be reached with Tab and used with Enter', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Tappable(label: 'Do it', onTap: () => taps++, child: const SizedBox(width: 80, height: 48)),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('tappable-focus')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(const ValueKey('tappable-focus')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('Tappable with no onTap does nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Tappable(label: 'Off', onTap: null, child: SizedBox(width: 80, height: 48)))),
    ));
    await tester.tap(find.byType(Tappable));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(const ValueKey('tappable-focus')), findsNothing);
  });

  testWidgets('Tappable is announced as a button with its label', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: Tappable(label: 'Take photo', onTap: () {}, child: const SizedBox(width: 60, height: 60)))),
    ));
    expect(find.bySemanticsLabel('Take photo'), findsOneWidget);
    h.dispose();
  });
}
