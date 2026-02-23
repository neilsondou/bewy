import 'dart:io';

import 'package:bewy/core/services/code_format_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CodeFormatService();

  group('CodeFormatService matrix', () {
    test('internal formatters improve readability on messy samples', () async {
      final samples = <(String file, String source, String tool)>[
        (
          'messy.dart',
          'void main(){final a=[1,2,3];if(a.isNotEmpty){print(a);}}',
          'dart_style',
        ),
        ('messy.json', '{"name":"bewy","langs":["dart","js"]}', 'json'),
        ('messy.xml', '<root><child id="1">x</child></root>', 'xml'),
      ];

      for (final sample in samples) {
        final (file, source, expectedTool) = sample;
        final result = await service.format(
          fileNameOrPath: file,
          source: source,
        );
        // ignore: avoid_print
        print(
          '[format-internal] file=$file supported=${result.supported} '
          'changed=${result.changed} tool=${result.tool}',
        );
        expect(result.supported, isTrue);
        expect(result.changed, isTrue);
        expect(result.formattedText, isNotNull);
        expect(result.tool, expectedTool);
      }
    });

    test(
      'js-like and related extensions are mapped to prettier support',
      () async {
        const extSamples = <(String file, String source)>[
          ('sample.js', 'function x(){return{a:1,b:2}}'),
          ('sample.jsx', 'const A=()=> <div><span>ok</span></div>;'),
          ('sample.ts', 'const n:number=1;export {n}'),
          ('sample.tsx', 'const A=()=> <main><h1>x</h1></main>;'),
          ('sample.css', 'body{margin:0;padding:0}'),
          ('sample.scss', 'body{.a{color:red}}'),
          ('sample.html', '<html><body><h1>x</h1></body></html>'),
          ('sample.yaml', 'a: 1\nb: [1,2]'),
          ('sample.md', '#title\n- a\n- b'),
        ];

        final prettierReady = await _hasCommand('prettier');
        // ignore: avoid_print
        print('[format-external] prettier_available=$prettierReady');

        for (final sample in extSamples) {
          final (file, source) = sample;
          final result = await service.format(
            fileNameOrPath: file,
            source: source,
          );
          // ignore: avoid_print
          print(
            '[format-external] file=$file supported=${result.supported} '
            'changed=${result.changed} tool=${result.tool} message=${result.message}',
          );

          expect(result.supported, isTrue);
          expect(result.tool, 'prettier');

          if (prettierReady) {
            expect(
              result.changed || (result.formattedText ?? '') != source,
              isTrue,
              reason:
                  'prettier is available but $file did not become more readable',
            );
          }
        }
      },
    );
  });
}

Future<bool> _hasCommand(String command) async {
  try {
    final result = await Process.run(command, ['--version'], runInShell: true);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
