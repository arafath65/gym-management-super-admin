import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_super_admin/main.dart';

void main() {
  testWidgets('Super Admin app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const GymSuperAdminApp());

    expect(find.text('SUPER ADMIN'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
