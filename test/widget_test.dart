import 'package:flutter_test/flutter_test.dart';

import 'package:kust/main.dart';

void main() {
  // 💡 Firebase 초기화 없이 검증 가능한 최소 스모크 테스트.
  //    초기화 실패 시 에러 화면이 뜨는지만 확인한다.
  testWidgets('Firebase 초기화 실패 시 에러 화면을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const KustApp(isInitialized: false));

    expect(find.text('서버 연결에 실패했습니다.'), findsOneWidget);
  });
}
