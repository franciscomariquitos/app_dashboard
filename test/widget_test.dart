import 'package:flutter_test/flutter_test.dart';

import 'package:pic/main.dart';

void main() {
  testWidgets('Dashboard renders monitor title', (WidgetTester tester) async {
    await tester.pumpWidget(const VitalSignsApp());

    expect(find.text('Vital Signs Monitor'), findsOneWidget);
  });
}
