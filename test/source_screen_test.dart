import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutu_player/screens/source_screen.dart';

void main() {
  testWidgets('dikey kaynak ekranı Xtream, tek yayın ve M3U gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SourceScreen()));

    expect(find.text('XTREAM'), findsOneWidget);
    expect(find.text('TEK YAYIN'), findsOneWidget);
    expect(find.text('M3U'), findsOneWidget);

    await tester.tap(find.text('XTREAM'));
    await tester.pumpAndSettle();
    expect(find.text('Playlist adı'), findsOneWidget);
    expect(find.text('Sunucu Adresi'), findsOneWidget);
    expect(find.text('Port'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('TEK YAYIN'));
    await tester.pumpAndSettle();
    expect(find.text('Yayın adresi'), findsOneWidget);

    FilledButton playButton() => tester.widget(find.widgetWithText(FilledButton, 'Oynat'));
    expect(playButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'https://example.com/live.m3u8');
    await tester.pump();
    expect(playButton().onPressed, isNotNull);
  });
}
