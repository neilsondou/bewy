import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/file_explorer/models/file_node.dart';

void main() {
  group('FileNode', () {
    test('default values for non-directory node', () {
      const node = FileNode(name: 'file.txt', path: '/tmp/file.txt');
      expect(node.isDirectory, isFalse);
      expect(node.isExpanded, isFalse);
      expect(node.children, isEmpty);
      expect(node.depth, 0);
    });

    test('directory node with children', () {
      const child = FileNode(
        name: 'child.txt',
        path: '/tmp/dir/child.txt',
        depth: 1,
      );
      const dir = FileNode(
        name: 'dir',
        path: '/tmp/dir',
        isDirectory: true,
        isExpanded: true,
        children: [child],
      );
      expect(dir.isDirectory, isTrue);
      expect(dir.isExpanded, isTrue);
      expect(dir.children.length, 1);
      expect(dir.children.first.name, 'child.txt');
    });

    test('copyWith toggles isExpanded', () {
      const node = FileNode(
        name: 'dir',
        path: '/tmp/dir',
        isDirectory: true,
        isExpanded: false,
      );
      final expanded = node.copyWith(isExpanded: true);
      expect(expanded.isExpanded, isTrue);
      expect(expanded.name, 'dir');
    });

    test('copyWith replaces children', () {
      const node = FileNode(name: 'dir', path: '/tmp/dir', isDirectory: true);
      final withChildren = node.copyWith(
        children: const [FileNode(name: 'a.txt', path: '/tmp/dir/a.txt')],
      );
      expect(withChildren.children.length, 1);
    });
  });
}
