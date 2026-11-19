import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maternalhealth_app/main.dart';
import 'package:maternalhealth_app/app_state.dart';
import 'package:maternalhealth_app/modules/patient/home/medicine_store.dart';

import 'package:maternalhealth_app/core/services/sync_service.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppState.instance),
          ChangeNotifierProvider.value(value: MedicineStore.instance),
          ChangeNotifierProvider.value(value: SyncService.instance),
        ],
        child: const MaternalHealthApp(),
      ),
    );

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
