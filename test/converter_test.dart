import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meican/ui/converter_page.dart';
import 'package:meican/ui/theme.dart';

void main() {
  testWidgets('千焦换算大卡及整包热量', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ConverterPage()),
    );

    await tester.enterText(find.byType(TextField).at(0), '418.4');
    await tester.pump();
    expect(find.text('100'), findsOneWidget);

    await tester.tap(find.text('整包热量'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '2000');
    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.enterText(find.byType(TextField).at(2), '250');
    await tester.pump();
    expect(find.text('1195'), findsOneWidget);
  });
}
