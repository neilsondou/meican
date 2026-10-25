import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meican/app_state.dart';
import 'package:meican/main.dart';
import 'package:meican/models.dart';
import 'package:meican/ui/meal_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('首页显示今日热量与记录入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(MeiCanApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsWidgets);
    expect(find.text('今天吃了什么'), findsOneWidget);
    expect(find.text('记一餐'), findsWidgets);
    expect(find.text('拍照识别'), findsWidgets);
  });

  testWidgets('底部标签可以在页面之间切换', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(MeiCanApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    expect(find.text('回看每一天'), findsOneWidget);

    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();
    expect(find.text('今天吃了什么'), findsOneWidget);
  });

  testWidgets('已保存的一餐可以编辑并且删除按钮没有下划线', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final now = DateTime.now();
    await state.addMeal(
      MealEntry(
        id: 'meal-1',
        date: now,
        mealType: '午餐',
        items: const [
          MealItem(id: 'item-1', name: '米饭', grams: 150, kcal: 174),
        ],
        note: '原记录',
        source: 'ai',
      ),
    );

    await tester.pumpWidget(MeiCanApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MealSummaryTile).first);
    await tester.pumpAndSettle();
    expect(find.text('编辑这一餐'), findsOneWidget);

    final deleteText = tester.widget<Text>(find.text('删除'));
    expect(deleteText.style?.decoration, TextDecoration.none);

    await tester.tap(find.text('编辑这一餐'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '其实只吃了半碗');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    final saved = state.meals.single;
    expect(saved.id, 'meal-1');
    expect(saved.date, now);
    expect(saved.mealType, '午餐');
    expect(saved.note, '其实只吃了半碗');
    expect(saved.source, 'ai');
    expect(saved.items.single.name, '米饭');
    expect(saved.items.single.grams, 150);
    expect(find.text('编辑这一餐'), findsNothing);
  });
}
