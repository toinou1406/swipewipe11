import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipewipe10/data/providers.dart';
import 'package:swipewipe10/main.dart';
import 'package:swipewipe10/screens/main_navigation_view.dart';

void main() {
  testWidgets('App starts with a loading indicator, then shows the main view', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override the mediaSyncProvider to control its state.
          // We start it in a loading state.
          mediaSyncProvider.overrideWith((ref) async {
            // This represents the async work being done.
            await Future.delayed(const Duration(milliseconds: 50));
          }),
          // We also need to provide a default for the albums provider,
          // as the home screen depends on it.
          albumsProvider.overrideWith((ref) async => []),
        ],
        child: const SwipeCleanApp(),
      ),
    );

    // At first, we should see the loading indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Syncing your media...'), findsOneWidget);

    // Pump the widget tree again to settle the FutureProvider.
    await tester.pumpAndSettle();

    // After the future completes, the loading indicator should be gone,
    // and the MainNavigationView should be present.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(MainNavigationView), findsOneWidget);

    // Verify that the initial screen is the Home screen (title 'SwipeClean').
    expect(find.text('SwipeClean'), findsOneWidget);
  });
}