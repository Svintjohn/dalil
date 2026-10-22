import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalil_app/theme.dart';
import 'package:dalil_app/widgets.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('PremiumCard shows its stripe only when asked', (tester) async {
    await tester.pumpWidget(_wrap(const PremiumCard(stripe: Colors.red, child: SizedBox(width: 120, height: 40))));
    expect(find.byKey(const ValueKey('card-stripe')), findsOneWidget);
    await tester.pumpWidget(_wrap(const PremiumCard(child: SizedBox(width: 120, height: 40))));
    expect(find.byKey(const ValueKey('card-stripe')), findsNothing);
  });

  testWidgets('PremiumCard rises under a pointer and settles back', (tester) async {
    await tester.pumpWidget(_wrap(const PremiumCard(child: SizedBox(width: 120, height: 40))));
    final before = tester.getTopLeft(find.byType(PremiumCard));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PremiumCard)));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumCard), findsOneWidget);
    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(PremiumCard)), before);
    await mouse.removePointer();
  });

  testWidgets('buttons get a visible focus ring in the theme', (tester) async {
    final t = buildTheme(Brightness.light);
    final side = t.filledButtonTheme.style!.side!.resolve({WidgetState.focused});
    expect(side, isNotNull);
    expect(side!.width, greaterThan(2));
  });
}