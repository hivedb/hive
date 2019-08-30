import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/box_options.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/box/lazy_box_impl.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'common.dart';

LazyBoxImpl getBox({
  String name,
  HiveImpl hive,
  StorageBackend backend,
  ChangeNotifier notifier,
  Keystore keystore,
  CompactionStrategy cStrategy,
}) {
  return LazyBoxImpl(
    hive ?? HiveImpl(),
    name ?? 'testBox',
    BoxOptions(
      compactionStrategy: cStrategy ?? (total, deleted) => false,
    ),
    backend ?? BackendMock(),
    keystore ?? Keystore(),
    notifier,
  );
}

void main() {
  group('LazyBoxImpl', () {
    test('.values', () {
      var box = getBox();

      expect(() => box.values, throwsUnsupportedError);
    });

    group('.get()', () {
      test('returns defaultValue if key does not exist', () async {
        var backend = BackendMock();
        var box = getBox(backend: backend);

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
        verifyZeroInteractions(backend);
      });

      test('reads value from backend', () async {
        var backend = BackendMock();
        when(backend.readValue(any, any, any))
            .thenAnswer((i) async => 'testVal');
        var box = getBox(
          backend: backend,
          keystore: Keystore(
            entries: {'testKey': BoxEntry('testVal', 123, 456)},
          ),
        );

        expect(await box.get('testKey'), 'testVal');
        verify(backend.readValue('testKey', 123, 456));
      });
    });

    test('.getAt()', () async {
      var keystore = Keystore(
        entries: {0: BoxEntry(null), 'a': BoxEntry(null)},
      );
      var backend = BackendMock();
      when(backend.readValue('a', any, any)).thenAnswer((i) async => 'A');
      var box = getBox(keystore: keystore, backend: backend);

      expect(await box.getAt(-1, defaultValue: 123), 123);
      expect(await box.getAt(1), 'A');
      expect(await box.getAt(2), null);
    });

    group('.put()', () {
      test('value', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(false);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.put('key1', 'value1');
        verifyInOrder([
          backend.writeFrame(Frame('key1', 'value1'), BoxEntry(null)),
          keystore.addAll({'key1': BoxEntry(null)}),
          notifier.notify('key1', 'value1', false),
        ]);
      });

      test('handles exceptions', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();

        when(backend.writeFrame(any, any)).thenThrow('Some error');
        when(keystore.containsKey(any)).thenReturn(true);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        expect(
            () async => await box.put('key1', 'newValue'), throwsA(anything));
        verifyInOrder(
            [backend.writeFrame(Frame('key1', 'newValue'), BoxEntry(null))]);
        verifyNoMoreInteractions(keystore);
        verifyNoMoreInteractions(notifier);
      });
    });

    group('.delete()', () {
      test('does nothing when deleting a non existing key', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(false);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.delete('testKey');
        verifyZeroInteractions(backend);
        verifyZeroInteractions(notifier);
      });

      test('delete key', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(true);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.delete('key1');
        verifyInOrder([
          keystore.containsKey('key1'),
          backend.writeFrame(Frame.deleted('key1'), null),
          keystore.deleteAll(['key1']),
          notifier.notify('key1', null, true),
        ]);
      });
    });

    group('.putAll()', () {
      test('values', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(false);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        verifyInOrder([
          backend.writeFrames(
            [Frame('key1', 'value1'), Frame('key2', 'value2')],
            [BoxEntry(null), BoxEntry(null)],
          ),
          keystore.addAll({'key1': BoxEntry(null), 'key2': BoxEntry(null)}),
          notifier.notify('key1', 'value1', false),
          notifier.notify('key2', 'value2', false),
        ]);
      });

      test('handles exceptions', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();

        when(backend.writeFrames(any, any)).thenThrow('Some error');
        when(keystore.containsKey(any)).thenReturn(true);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await expectLater(
          () async => await box.putAll({'key1': 'value1', 'key2': 'value2'}),
          throwsA(anything),
        );
        verifyInOrder([
          backend.writeFrames(
            [Frame('key1', 'value1'), Frame('key2', 'value2')],
            [BoxEntry(null), BoxEntry(null)],
          ),
        ]);
        verifyNoMoreInteractions(keystore);
        verifyNoMoreInteractions(notifier);
      });
    });

    group('.deleteAll()', () {
      test('does nothing when deleting non existing keys', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(false);
        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.deleteAll(['key1', 'key2', 'key3']);
        verifyZeroInteractions(backend);
        verifyZeroInteractions(notifier);
      });

      test('delete keys', () async {
        var backend = BackendMock();
        var keystore = KeystoreMock();
        var notifier = ChangeNotifierMock();
        when(keystore.containsKey(any)).thenReturn(true);

        var box = getBox(
          backend: backend,
          keystore: keystore,
          notifier: notifier,
        );

        await box.deleteAll(['key1', 'key2']);
        verifyInOrder([
          keystore.containsKey('key1'),
          keystore.containsKey('key2'),
          backend.writeFrames(
            [Frame.deleted('key1'), Frame.deleted('key2')],
            null,
          ),
          keystore.deleteAll(['key1', 'key2']),
          notifier.notify('key1', null, true),
          notifier.notify('key2', null, true),
        ]);
      });
    });

    test('.toMap()', () async {
      var box = getBox();
      expect(box.toMap, throwsUnsupportedError);
    });
  });
}
