import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/main.dart';

void main() {
  testWidgets('shows the three modes', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: InvestorGameApp()));
    expect(find.text('Pure Game'), findsOneWidget);
    expect(find.text('Story Mode'), findsOneWidget);
    expect(find.text('Pure Edu'), findsOneWidget);
  });
}
