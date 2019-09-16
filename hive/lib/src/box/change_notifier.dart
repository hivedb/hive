import 'dart:async';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/query/hive_results_live_impl.dart';
import 'package:meta/meta.dart';

class ChangeNotifier {
  final StreamController<BoxEvent> _streamController;

  ChangeNotifier() : _streamController = StreamController<BoxEvent>.broadcast();

  @visibleForTesting
  ChangeNotifier.debug(this._streamController);

  void notify(Iterable<Frame> frames) {
    for (var frame in frames) {
      _streamController.add(BoxEvent(frame.key, frame.value, frame.deleted));
    }
  }

  Stream<BoxEvent> watch({dynamic key}) {
    if (key != null) {
      return _streamController.stream.where((it) => it.key == key);
    } else {
      return _streamController.stream;
    }
  }

  Future<void> close() {
    return _streamController.close();
  }
}
