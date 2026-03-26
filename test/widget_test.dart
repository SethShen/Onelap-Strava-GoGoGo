import 'package:flutter_test/flutter_test.dart';

import 'package:onelap_strava_sync/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OneLapStravaApp());
    expect(find.byType(OneLapStravaApp), findsOneWidget);
  });
}
