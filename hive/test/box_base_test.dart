import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/box/box_base.dart';
import 'package:hive/src/box/box_options.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'common.dart';

class BoxBaseMock extends BoxBase with Mock {
  BoxBaseMock() : super(null, null, null, null);

  BoxBaseMock.debug({
    HiveImpl hive,
    String name,
    bool lazy,
    StorageBackend backend,
    Keystore keystore,
    ChangeNotifier notifier,
    CompactionStrategy cStrategy,
  }) : super.debug(
          hive ?? HiveImpl(),
          name ?? 'testBox',
          BoxOptions(
            lazy: lazy ?? false,
            compactionStrategy: cStrategy ?? (total, deleted) => false,
          ),
          backend ?? BackendMock(),
          keystore ?? Keystore(),
          notifier ?? ChangeNotifier(),
        );
}

void main() {
  group('BoxBase', () {
    test('.name', () {
      var box = BoxBaseMock.debug(name: 'testName');
      expect(box.name, 'testName');
    });

    test('.path', () {
      var backend = BackendMock();
      when(backend.path).thenReturn('some/path');
      var box = BoxBaseMock.debug(backend: backend);
      expect(box.path, 'some/path');
    });

    test('.keys', () {
      var keystore = Keystore({
        'key1': BoxEntry(null),
        'key2': BoxEntry(null),
        'key4': BoxEntry(null)
      });
      var box = BoxBaseMock.debug(keystore: keystore);
      expect(box.keys, ['key1', 'key2', 'key4']);
    });

    test('.has()', () {
      var backend = BackendMock();
      var box = BoxBaseMock.debug(
        backend: backend,
        keystore: Keystore({
          'existingKey': BoxEntry(null),
        }),
      );

      expect(box.has('existingKey'), true);
      expect(box.has('nonExistingKey'), false);
      verifyZeroInteractions(backend);
    });

    test('.delete()', () {
      var box = BoxBaseMock.debug();
      box.delete('testKey');
      verify(box.put('testKey', null));
    });

    test('.deleteAll()', () {
      var box = BoxBaseMock.debug();
      box.deleteAll(['key1', 'key2', 'key3']);
      verify(box.putAll({'key1': null, 'key2': null, 'key3': null}));
    });

    test('.clear()', () async {
      var backend = BackendMock();
      var notifier = ChangeNotifierMock();
      var box = BoxBaseMock.debug(
        backend: backend,
        notifier: notifier,
        keystore: Keystore({'key1': BoxEntry(null), 'key2': BoxEntry(null)}),
      );

      expect(await box.clear(), 2);
      //expect(box.debugDeletedEntries, 0);
      verify(backend.clear());
      verify(notifier.notify('key1', null));
    });

    group('.compact()', () {
      test('does nothing if there are no deleted entries', () async {
        var backend = BackendMock();
        var box = BoxBaseMock.debug(
          backend: backend,
          keystore: Keystore({
            'key1': BoxEntry(null),
          }),
        );
        await box.compact();
        verifyZeroInteractions(backend);
      });
    });

    test('.close()', () async {
      var hive = HiveMock();
      var notifier = ChangeNotifierMock();
      var backend = BackendMock();
      var box = BoxBaseMock.debug(
        name: 'myBox',
        hive: hive,
        notifier: notifier,
        backend: backend,
      );

      await box.close();
      verifyInOrder([
        notifier.close(),
        hive.unregisterBox('myBox'),
        backend.close(),
      ]);
      expect(box.isOpen, false);
    });

    test('.deleteFromDisk()', () async {
      var hive = HiveMock();
      var notifier = ChangeNotifierMock();
      var backend = BackendMock();
      var box = BoxBaseMock.debug(
        name: 'myBox',
        hive: hive,
        notifier: notifier,
        backend: backend,
      );

      await box.deleteFromDisk();
      verifyInOrder([
        notifier.close(),
        hive.unregisterBox('myBox'),
        backend.deleteFromDisk(),
      ]);
      expect(box.isOpen, false);
    });
  });
}