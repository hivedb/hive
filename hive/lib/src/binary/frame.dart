import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:hive/src/util/crc32.dart';

class Frame {
  final dynamic key;
  final dynamic value;

  final int length;
  final bool deleted;
  final bool lazy;

  const Frame(this.key, this.value, [this.length])
      : lazy = false,
        deleted = false;
  //assert(key is int || (key is String && key.length <= 255),
  //'Unsupported key');

  const Frame.deleted(this.key, [this.length])
      : value = null,
        lazy = false,
        deleted = true;

  const Frame.lazy(this.key, [this.length])
      : value = null,
        lazy = true,
        deleted = false;

  static Frame fromBytes(
      Uint8List bytes, TypeRegistry registry, CryptoHelper crypto) {
    var lengthBytes = Uint8List.view(bytes.buffer, 0, 4);
    var frameBytes = Uint8List.view(bytes.buffer, 4);
    if (!checkCrc(lengthBytes, frameBytes, crypto?.keyCrc)) {
      throw HiveError('Wrong checksum in hive file. Box may be corrupted.');
    }

    var frameReader =
        BinaryReaderImpl(frameBytes, registry, frameBytes.length - 4);
    return decode(frameReader, false, bytes.length, crypto);
  }

  static Frame decode(
    BinaryReaderImpl reader,
    bool lazy,
    int frameLength,
    CryptoHelper crypto,
  ) {
    dynamic key;
    var keyType = reader.readByte();
    if (keyType == FrameKeyType.uintT.index) {
      key = reader.readUint32();
    } else {
      var keyLength = reader.readByte(); // Read length of key
      key = reader.readAsciiString(keyLength); // Read key
    }

    if (reader.availableBytes == 0) {
      return Frame.deleted(key, frameLength);
    } else if (lazy) {
      return Frame.lazy(key, frameLength);
    } else {
      var value = decodeValue(reader, crypto);
      return Frame(key, value, frameLength);
    }
  }

  static dynamic decodeValue(
    BinaryReaderImpl reader,
    CryptoHelper crypto,
  ) {
    dynamic value;
    if (crypto == null) {
      value = reader.read();
    } else {
      var encryptedBytes = reader.viewBytes(reader.availableBytes);
      var decryptedBytes = crypto.decrypt(encryptedBytes);
      var valueReader = BinaryReaderImpl(decryptedBytes, reader.typeRegistry);
      value = valueReader.read();
    }

    if (reader.availableBytes > 0) {
      throw HiveError('Not all bytes have been used.');
    }

    return value;
  }

  Uint8List toBytes(TypeRegistry registry, CryptoHelper crypto) {
    var writer = BinaryWriterImpl(registry);

    // Placeholder for length
    writer.writeByteList([0, 0, 0, 0], writeLength: false);

    var localKey = key;
    if (localKey is String) {
      writer
        ..writeByte(FrameKeyType.asciiStringT.index)
        ..writeByte(localKey.length) // Write key length
        ..writeAsciiString(localKey, writeLength: false); // Write key

    } else {
      writer
        ..writeByte(FrameKeyType.uintT.index)
        ..writeUint32(localKey as int); // Write key
    }

    if (!deleted) {
      encodeValue(value, writer, crypto);
    }

    writer
        .writeByteList([0, 0, 0, 0], writeLength: false); // Placeholder for CRC

    var bytes = writer.output();

    var byteData = ByteData.view(bytes.buffer);
    byteData.setUint32(0, bytes.length, Endian.little); // Write length

    var bytesWithoutCRC = Uint8List.view(bytes.buffer, 0, bytes.length - 4);
    var checksum = Crc32.compute(bytesWithoutCRC, crc: crypto?.keyCrc ?? 0);

    byteData.setUint32(bytes.length - 4, checksum, Endian.little);

    return bytes;
  }

  static void encodeValue(
      dynamic value, BinaryWriterImpl writer, CryptoHelper crypto) {
    if (crypto == null) {
      writer.write(value); // Write value
    } else {
      var valueWriter = BinaryWriterImpl(writer.typeRegistry)..write(value);
      var encryptedValue = crypto.encrypt(valueWriter.output());
      writer.writeByteList(encryptedValue, writeLength: false);
    }
  }

  static bool checkCrc(
      List<int> lengthBytes, List<int> frameBytes, int keyCrc) {
    var computedCrc = keyCrc ?? 0;
    if (lengthBytes != null) {
      computedCrc = Crc32.compute(lengthBytes, crc: computedCrc);
    }
    computedCrc = Crc32.compute(frameBytes,
        crc: computedCrc, length: frameBytes.length - 4);

    var crc = bytesToUint32(frameBytes, frameBytes.length - 4);
    return computedCrc == crc;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is Frame) {
      return key == other.key &&
          value == other.value &&
          length == other.length &&
          deleted == other.deleted;
    } else {
      return false;
    }
  }
}

enum FrameKeyType {
  uintT,
  asciiStringT,
}

enum FrameValueType {
  nullT,
  intT,
  doubleT,
  boolT,
  stringT,
  byteListT,
  intListT,
  doubleListT,
  boolListT,
  stringListT,
  listT,
  mapT,
}

int bytesToUint32(List<int> bytes, [int offset = 0]) {
  return bytes[offset] |
      bytes[offset + 1] << 8 |
      bytes[offset + 2] << 16 |
      bytes[offset + 3] << 24;
}
