import 'package:flutter_test/flutter_test.dart';
import 'package:media_lightbox_example/main.dart';

void main() {
  testWidgets('example app builds', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(ExampleApp), findsOneWidget);
  });
}
