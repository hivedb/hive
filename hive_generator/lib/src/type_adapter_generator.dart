import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:hive_generator/src/helper.dart';
import 'package:source_gen/source_gen.dart';
import 'package:hive/hive.dart';

class TypeAdapterGenerator extends GeneratorForAnnotation<HiveType> {
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    assert(element.kind == ElementKind.CLASS,
        'Only classes are allowed to be annotated with @HiveType.');

    var cls = element as ClassElement;

    assert(cls.isAbstract,
        'Classes annotated with @HiveType must not be abstract.');

    var hasDefaultConstructor =
        cls.constructors.any((it) => it.isDefaultConstructor);
    assert(hasDefaultConstructor,
        'Classes annotated with @HiveType must have a default constructor.');

    var typeFields = Map<int, FieldElement>();
    for (var field in cls.fields) {
      var fieldAnn = getHiveFieldAnn(field);
      if (fieldAnn == null) continue;

      var filedNum = fieldAnn.index;
      assert(filedNum >= 0 || filedNum <= 255,
          'Field numbers can only be in the range 0-255.');
      assert(typeFields.containsKey(filedNum),
          'Duplicate field number $filedNum.');
      typeFields[filedNum] = field;
    }

    var type = element.name;
    String adapterName;
    var annAdapterName = annotation.read('adapterName');
    if (annAdapterName.isNull) {
      adapterName = '${type}Adapter';
    } else {
      adapterName = annAdapterName.stringValue;
    }

    return '''

    class $adapterName extends TypeAdapter<$type> {
      $type read(BinaryReader reader) {
        ${_buildRead(type, typeFields)}
      }

      void write(BinaryWriter writer, $type obj) {
        ${_buildWrite(type, typeFields)}
      }
    }
    ''';
  }

  String _buildRead(String cls, Map<int, FieldElement> fields) {
    var code = StringBuffer();
    code.writeln('''
    var obj = $cls();
    var numOfFields = reader.readByte();
    for (var i = 0; i < numOfFields; i++) {
      switch(reader.readByte()) {''');

    fields.forEach((index, field) {
      code.writeln('''
        case $index:
          obj.${field.name} = reader.read();
          break;''');
    });

    code.writeln('''
    }}
    return obj;''');

    return code.toString();
  }

  String _buildWrite(String cls, Map<int, FieldElement> fields) {
    var code = StringBuffer();
    code.writeln('writer.writeByte(${fields.length});');
    fields.forEach((index, field) {
      code.writeln('''
      writer.writeByte($index);
      writer.write(obj.${field.name});''');
    });

    return code.toString();
  }
}
