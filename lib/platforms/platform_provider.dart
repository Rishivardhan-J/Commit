import '../data/models.dart';

class PlatformException implements Exception {
  final String message;
  PlatformException(this.message);
  @override
  String toString() => message;
}

/// One implementation per coding platform; failures stay isolated to that platform.
abstract class PlatformProvider {
  String get id;
  Future<PlatformSnapshot> fetch(String username);
}
