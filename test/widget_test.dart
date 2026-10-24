import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meican/app_state.dart';
import 'package:meican/main.dart';
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
}
