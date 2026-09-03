import 'package:flutter_test/flutter_test.dart';
import 'package:jeda/main.dart';
import 'package:jeda/core/services/storage_service.dart';

void main() {
  testWidgets('Smoke test JedaApp instantiation', (WidgetTester tester) async {
    final storageService = StorageService();
    await tester.pumpWidget(JedaApp(storageService: storageService));
    expect(find.byType(JedaApp), findsOneWidget);
  });
}
