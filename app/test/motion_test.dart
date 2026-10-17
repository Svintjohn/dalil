import 'package:dalil_app/motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smooth spring starts at 0, ends at 1 and never overshoots', () {
    const c = AppleSpring();
    expect(c.transform(0), 0);
    expect(c.transform(1), 1);
    for (var i = 1; i < 100; i++) {
      final v = c.transform(i / 100);
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });

  test('lively spring overshoots a little', () {
    const c = AppleSpring(bounce: 0.15);
    var peak = 0.0;
    for (var i = 1; i < 100; i++) {
      final v = c.transform(i / 100);
      if (v > peak) peak = v;
    }
    expect(peak, greaterThan(1.0));
    expect(peak, lessThan(1.1));
  });
}
