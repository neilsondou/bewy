import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bewy/app.dart';
import 'package:bewy/features/shell/presentation/ide_shell.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BewyApp()));
    await tester.pumpAndSettle();
    expect(find.byType(IDEShell), findsOneWidget);
  });
}
