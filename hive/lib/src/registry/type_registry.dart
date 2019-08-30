part of hive;

/// An adapter - typeId pair.
class ResolvedAdapter<T> {
  final TypeAdapter adapter;
  final int typeId;

  const ResolvedAdapter(this.adapter, this.typeId);

  bool matches(dynamic value) => value is T;
}

/// TypeRegistries contain the [TypeAdapter]s associated with a typeId.
///
/// TypeIds have to be unique and must not change.
abstract class TypeRegistry {
  static const minCustomTypeId = 33;

  /// Get the [TypeAdapter] associated with the [typeId].
  ///
  /// Hive uses this method to read objects. You will probably not need it.
  ResolvedAdapter findAdapterForTypeId(int typeId);

  /// Get the [TypeAdapter] which supports this [value].
  ///
  /// Hive uses this method to write objects. You will probably not need it.
  ResolvedAdapter findAdapterForValue(dynamic value);

  /// Register a [TypeAdapter] to announce it to Hive.
  ///
  /// This is a nessecary step before custom adapter can be used by Hive.
  void registerAdapter<T>(TypeAdapter<T> adapter, int typeId);
}
