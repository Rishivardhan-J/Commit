import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:commit/core/theme/app_theme.dart';
import 'package:commit/core/widgets/confirm_dialog.dart';

void main() {
  Future<void> pumpHost(WidgetTester t, void Function(bool) onResult) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(await confirmDestructive(c, title: 'Delete task?', message: 'Gone.')),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
  }

  testWidgets('Cancel resolves false', (t) async {
    bool? got;
    await pumpHost(t, (v) => got = v);
    expect(find.text('Delete task?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(got, false);
  });

  testWidgets('Delete resolves true', (t) async {
    bool? got;
    await pumpHost(t, (v) => got = v);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(got, true);
  });

  test('no emoji in app source (share text is the only exception)', () {
    final emoji = RegExp('[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true);
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final line in f.readAsLinesSync()) {
        if (emoji.hasMatch(line) && !line.contains('committed on Commit')) hits.add('${f.path}: $line');
      }
    }
    expect(hits, isEmpty);
  });
}
