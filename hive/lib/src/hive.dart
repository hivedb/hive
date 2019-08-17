part of hive;

abstract class HiveInterface implements TypeRegistry {
  /// The home directory of Hive.
  ///
  /// All box files will be stored in this directory.
  String get path;

  /// Initialize Hive by giving it a home directory.
  void init(String path);

  /// Open a box
  Future<Box> box(
    String name, {
    List<int> encryptionKey,
    CompactionStrategy compactionStrategy,
    bool crashRecovery = true,
  });

  Future<LazyBox> lazyBox(
    String name, {
    List<int> encryptionKey,
    CompactionStrategy compactionStrategy,
    bool crashRecovery = true,
  });

  /// Checks if a specific box is currently open.
  bool isBoxOpen(String name);

  Box operator [](String name);

  /// Closes all open boxes and then Hive itself.
  Future<void> close();

  /// Deletes all boxes from disk.
  ///
  /// The home directoy will not be deleted.
  Future<void> deleteFromDisk();

  /// Generates a secure encryption key using the fortuna random algorithm.
  List<int> generateSecureKey();
}

typedef CompactionStrategy = bool Function(int entries, int deletedEntries);
