import 'package:commit/core/widgets/commit_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CommitLogo paints as tile and bare mark without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Row(children: [CommitLogo(size: 96), CommitLogo(size: 24, tile: false)])),
    ));
    expect(find.bySemanticsLabel('Commit logo'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
