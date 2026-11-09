import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release manifest declares INTERNET (debug/profile add it separately, release does not)', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android.permission.INTERNET'));
  });
}
