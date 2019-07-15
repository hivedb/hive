import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';

class BinaryReaderImpl extends BinaryReader {
  final Uint8List _buffer;
  final int _bufferLength;
  final ByteData _data;
  final TypeRegistry typeRegistry;
  int _offset = 0;

  BinaryReaderImpl(this._buffer, this.typeRegistry, [int bufferLength])
      : _bufferLength = bufferLength ?? _buffer.length,
        _data = ByteData.view(_buffer.buffer, _buffer.offsetInBytes,
            bufferLength ?? _buffer.length);

  int get _bufferOffset => _buffer.offsetInBytes + _offset;

  @override
  int get availableBytes => _bufferLength - _offset;

  @override
  int get usedBytes => _offset;

  Uint8List get buffer => _buffer;

  void _requireBytes(int bytes) {
    if (_bufferLength - _offset < bytes) {
      throw RangeError('Not enough bytes available.');
    }
  }

  @override
  void skip(int bytes) {
    _requireBytes(bytes);
    _offset += bytes;
  }

  @override
  int readByte() {
    _requireBytes(1);
    return _buffer[_offset++];
  }

  @override
  Uint8List viewBytes(int bytes) {
    _requireBytes(bytes);
    var view = Uint8List.view(_buffer.buffer, _bufferOffset, bytes);
    _offset += bytes;
    return view;
  }

  @override
  int readWord() {
    _requireBytes(2);
    return _buffer[_offset++] | _buffer[_offset++] << 8;
  }

  @override
  int readInt32() {
    _requireBytes(4);
    var value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  @override
  int readUint32() {
    _requireBytes(4);
    return _buffer[_offset++] |
        _buffer[_offset++] << 8 |
        _buffer[_offset++] << 16 |
        _buffer[_offset++] << 24;
  }

  @override
  int readInt() {
    return readDouble().toInt();
  }

  @override
  double readDouble() {
    _requireBytes(8);
    var value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  @override
  bool readBool() {
    _requireBytes(1);
    return _buffer[_offset++] > 0;
  }

  @override
  String readString(
      [int byteCount,
      Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    if (byteCount == null) {
      byteCount = readWord();
    }
    var view = viewBytes(byteCount);
    return decoder.convert(view);
  }

  @override
  String readAsciiString([int length]) {
    if (length == null) {
      length = readWord();
    }
    var view = viewBytes(length);
    var str = String.fromCharCodes(view);
    return str;
  }

  @override
  Uint8List readByteList([int length]) {
    if (length == null) {
      length = readWord();
    }
    _requireBytes(length);
    var byteList = _buffer.sublist(_offset, _offset + length);
    _offset += length;
    return byteList as Uint8List;
  }

  @override
  List<int> readIntList([int length]) {
    if (length == null) {
      length = readWord();
    }
    _requireBytes(length * 8);
    var list = List<int>(length);
    for (var i = 0; i < length; i++) {
      list[i] = _data.getFloat64(_offset, Endian.little).toInt();
      _offset += 8;
    }
    return list;
  }

  @override
  List<double> readDoubleList([int length]) {
    if (length == null) {
      length = readWord();
    }
    _requireBytes(length * 8);
    var list = List<double>(length);
    for (var i = 0; i < length; i++) {
      list[i] = _data.getFloat64(_offset, Endian.little);
      _offset += 8;
    }
    return list;
  }

  @override
  List<bool> readBoolList([int length]) {
    if (length == null) {
      length = readWord();
    }
    _requireBytes(length);
    var list = List<bool>(length);
    for (var i = 0; i < length; i++) {
      list[i] = _buffer[_offset++] > 0;
    }
    return list;
  }

  @override
  List<String> readStringList(
      [int length,
      Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    if (length == null) {
      length = readWord();
    }
    var list = List<String>(length);
    for (var i = 0; i < length; i++) {
      list[i] = readString(null, decoder);
    }
    return list;
  }

  @override
  List readList([int length]) {
    if (length == null) {
      length = readWord();
    }
    var list = List(length);
    for (var i = 0; i < length; i++) {
      list[i] = read();
    }
    return list;
  }

  @override
  Map readMap([int length]) {
    if (length == null) {
      length = readWord();
    }
    Map map = Map();
    for (var i = 0; i < length; i++) {
      var key = read();
      var value = read();
      map[key] = value;
    }
    return map;
  }

  @override
  dynamic read([int typeId]) {
    if (typeId == null) {
      typeId = readByte();
    }
    if (typeId < FrameValueType.values.length) {
      var typeEnum = FrameValueType.values[typeId];
      switch (typeEnum) {
        case FrameValueType.null_:
          return null;
        case FrameValueType.int_:
          return readInt();
        case FrameValueType.double_:
          return readDouble();
        case FrameValueType.bool_:
          return readBool();
        case FrameValueType.string_:
          return readString();
        case FrameValueType.byte_list_:
          return readByteList();
        case FrameValueType.int_list_:
          return readIntList();
        case FrameValueType.double_list_:
          return readDoubleList();
        case FrameValueType.bool_list_:
          return readBoolList();
        case FrameValueType.string_list_:
          return readStringList();
        case FrameValueType.list_:
          return readList();
        case FrameValueType.map_:
          return readMap();
      }
    } else {
      var resolved = typeRegistry.findAdapterForTypeId(typeId);
      if (resolved == null) {
        throw HiveError('Cannot read, unknown typeId: $typeId.');
      }
      return resolved.adapter.read(this);
    }
  }
}
