import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:current_affairs_pro/core/network/api_client.dart';
import 'package:current_affairs_pro/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ApiClient(),
        child: const CurrentAffairsProApp(),
      ),
    );

    // Verify that the loading splash screen displays the app branding
    expect(find.byIcon(Icons.newspaper_rounded), findsOneWidget);
    expect(find.text('Current Affairs Pro'), findsOneWidget);
  });
}
