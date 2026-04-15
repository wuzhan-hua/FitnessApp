import 'package:fitness_client/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders 4 tabs and switches to calendar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessApp()));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.textContaining('年'), findsWidgets);
  });

  testWidgets('home page key sections are visible', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessApp()));
    await tester.pumpAndSettle();

    expect(find.text('A. 今日状态'), findsOneWidget);
    expect(find.text('B. 主操作区'), findsOneWidget);
    expect(find.text('E. 近7天概览'), findsOneWidget);
  });
}
