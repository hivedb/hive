import 'package:hive/hive.dart';

/// Not part of public API
class IgnoredTypeAdapter<T> implements TypeAdapter<T?> {
  const IgnoredTypeAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  dynamic defaultKey(obj) {
      return null;
  }

  @override
  T? read(BinaryReader reader) => null;

  @override
  void write(BinaryWriter writer, obj) {}
}
