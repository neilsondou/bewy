import 'package:bewy/core/services/code_format_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CodeFormatService();

  test('formats json with internal formatter', () async {
    final result = await service.format(
      fileNameOrPath: 'sample.json',
      source: '{"a":1,"b":{"c":2}}',
    );
    expect(result.supported, isTrue);
    expect(result.formattedText, contains('\n'));
    expect(result.formattedText, contains('"a": 1'));
  });

  test('returns unsupported for unknown extension', () async {
    final result = await service.format(
      fileNameOrPath: 'README.unknownext',
      source: 'abc',
    );
    expect(result.supported, isFalse);
  });
}
