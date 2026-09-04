// Basic smoke test for the Fiumicello app shell.
import 'package:flutter_test/flutter_test.dart';

import 'package:fiumicello_frontend/app.dart';
import 'package:fiumicello_frontend/navigation/app_shell.dart';

void main() {
  testWidgets('App shell builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const FiumicelloApp());
    // The shell renders the Material app and the top-level shell.
    expect(find.byType(AppShell), findsOneWidget);
  });
}