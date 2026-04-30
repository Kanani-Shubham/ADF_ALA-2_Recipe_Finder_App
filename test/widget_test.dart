import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipefinder/main.dart';

void main() {
  testWidgets('Veg Recipe AI splash renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VegRecipeApp()));

    expect(find.text('Veg Recipe AI'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsOneWidget);
  });
}
