import 'package:flutter_test/flutter_test.dart';
import 'package:udhar_khata/main.dart';
import 'package:udhar_khata/services/udhar_repository.dart';

void main() {
  testWidgets('UdharKhataApp renders Dashboard title and Add Customer FAB', (WidgetTester tester) async {
    final repository = UdharRepository(null);

    await tester.pumpWidget(UdharKhataApp(repository: repository));

    expect(find.text('Udhar Khata'), findsOneWidget);
    expect(find.text('Add Customer'), findsOneWidget);
    expect(find.text('Total Outstanding Debt'), findsOneWidget);
  });
}
