import 'signature.dart';

Map<String, String> fieldMap(Iterable<FormFieldPair> fields) =>
    <String, String>{for (final FormFieldPair field in fields) field.name: field.value};

String? fieldValue(Iterable<FormFieldPair> fields, String name) {
  for (final FormFieldPair field in fields) {
    if (field.name == name) return field.value;
  }
  return null;
}
