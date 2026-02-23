import 'package:bewy/core/services/code_format_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CodeFormatService();

  group('CodeFormatService full language coverage', () {
    test(
      'internal formatters (dart/json/xml/svg) should produce readable output',
      () async {
        final internalCases = <_SampleCase>[
          _SampleCase(
            fileName: 'messy.dart',
            source: 'void main(){final a=[1,2,3];if(a.isNotEmpty){print(a);}}',
            expectedTool: 'dart_style',
          ),
          _SampleCase(
            fileName: 'messy.json',
            source: '{"a":1,"b":{"c":2},"d":[1,2,3]}',
            expectedTool: 'json',
          ),
          _SampleCase(
            fileName: 'messy.xml',
            source: '<root><child id="1">x</child><n/></root>',
            expectedTool: 'xml',
          ),
          _SampleCase(
            fileName: 'messy.svg',
            source:
                '<svg><g><rect width="10" height="10"></rect><circle r="4"></circle></g></svg>',
            expectedTool: 'xml',
          ),
        ];

        for (final sample in internalCases) {
          final result = await service.format(
            fileNameOrPath: sample.fileName,
            source: sample.source,
          );
          // ignore: avoid_print
          print(
            '[internal] ${sample.fileName} -> supported=${result.supported}, '
            'changed=${result.changed}, tool=${result.tool}, message=${result.message}',
          );
          expect(result.supported, isTrue);
          expect(result.changed, isTrue);
          expect(result.tool, sample.expectedTool);
          expect(result.formattedText, isNotNull);
          expect(result.formattedText, isNot(sample.source));
        }
      },
    );

    test(
      'external mapped languages should be recognized and report effective/non-effective',
      () async {
        final externalCases = <_SampleCase>[
          // prettier-family
          _SampleCase(
            fileName: 'sample.js',
            source: 'function x(){return{a:1,b:2}}',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.jsx',
            source: 'const A=()=> <div><span>ok</span></div>;',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.ts',
            source: 'type T={a:number};const n:T={a:1};export{n}',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.tsx',
            source: 'const App=()=> <main><h1>x</h1></main>;',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.css',
            source: 'body{margin:0;padding:0}',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.scss',
            source: '.box{.title{color:red}}',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.html',
            source: '<html><body><h1>x</h1></body></html>',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.yml',
            source: 'a: 1\nb: [1,2]\n',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.yaml',
            source: 'name: bewy\nlist: [a,b]\n',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.md',
            source: '#title\n- a\n- b',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.vue',
            source:
                '<template><div><h1>Hi</h1></div></template><script setup lang="ts">const a=1</script>',
            expectedTool: 'prettier',
          ),
          _SampleCase(
            fileName: 'sample.svelte',
            source: '<script>let count=0</script><h1>{count}</h1>',
            expectedTool: 'prettier',
          ),
          // single-language external tools
          _SampleCase(
            fileName: 'sample.py',
            source: 'def add(a,b):\n return a+b\n',
            expectedTool: 'black',
          ),
          _SampleCase(
            fileName: 'sample.go',
            source: 'package main\nfunc main(){println("x")}\n',
            expectedTool: 'gofmt',
          ),
          _SampleCase(
            fileName: 'sample.rs',
            source: 'fn main(){println!("x");}\n',
            expectedTool: 'rustfmt',
          ),
          _SampleCase(
            fileName: 'sample.c',
            source: 'int main(){int x=1;return x;}',
            expectedTool: 'clang-format',
          ),
          _SampleCase(
            fileName: 'sample.cpp',
            source: 'int main(){int x=1;return x;}',
            expectedTool: 'clang-format',
          ),
          _SampleCase(
            fileName: 'sample.cs',
            source: 'class A{static void Main(){var x=1;}}',
            expectedTool: 'clang-format',
          ),
          _SampleCase(
            fileName: 'sample.java',
            source: 'class A{public static void main(String[]a){int x=1;}}',
            expectedTool: 'clang-format',
          ),
        _SampleCase(
          fileName: 'sample.sh',
          source: r'if [ "$a" = "1" ];then echo hi;fi',
          expectedTool: 'shfmt',
        ),
        _SampleCase(
          fileName: 'sample.bash',
          source: r'if [ "$a" = "1" ];then echo hi;fi',
          expectedTool: 'shfmt',
        ),
        _SampleCase(
          fileName: 'sample.zsh',
          source: r'if [ "$a" = "1" ];then echo hi;fi',
          expectedTool: 'shfmt',
        ),
          _SampleCase(
            fileName: 'sample.lua',
            source: 'function f(a,b)return a+b end',
            expectedTool: 'stylua',
          ),
        ];

        final effective = <String>[];
        final ineffective = <String>[];

        for (final sample in externalCases) {
          final result = await service.format(
            fileNameOrPath: sample.fileName,
            source: sample.source,
          );
          // ignore: avoid_print
          print(
            '[external] ${sample.fileName} -> supported=${result.supported}, '
            'changed=${result.changed}, tool=${result.tool}, message=${result.message}',
          );

          expect(
            result.supported,
            isTrue,
            reason: '${sample.fileName} should be mapped as supported',
          );
          expect(
            result.tool,
            sample.expectedTool,
            reason: '${sample.fileName} should map to ${sample.expectedTool}',
          );

          final becameReadable =
              result.changed &&
              result.formattedText != null &&
              result.formattedText != sample.source;
          if (becameReadable) {
            effective.add(sample.fileName);
          } else {
            ineffective.add(
              '${sample.fileName} (tool=${result.tool}, message=${result.message ?? 'none'})',
            );
          }
        }

        // ignore: avoid_print
        print('[summary] external effective=${effective.length}: $effective');
        // ignore: avoid_print
        print(
          '[summary] external ineffective=${ineffective.length}: $ineffective',
        );
      },
    );
  });
}

class _SampleCase {
  const _SampleCase({
    required this.fileName,
    required this.source,
    required this.expectedTool,
  });

  final String fileName;
  final String source;
  final String expectedTool;
}
