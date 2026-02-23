import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:bewy/features/file_explorer/widgets/file_icon.dart';
import 'package:bewy/core/providers/file_icon_theme_provider.dart';

void main() {
  // ── File icon mapping tests ─────────────────────────────────────────
  group('FileIcon - file extension mapping', () {
    Widget buildFileIcon(String name) {
      return MaterialApp(home: Scaffold(body: FileIcon(name: name)));
    }

    testWidgets('dart files show flutter_dash icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('main.dart'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.flutter_dash);
    });

    testWidgets('python files show languagePython icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('script.py'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languagePython);
    });

    testWidgets('c files show languageC icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('main.c'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageC);
    });

    testWidgets('cpp files show languageCpp icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('shapes.cpp'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageCpp);
    });

    testWidgets('java files show languageJava icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('App.java'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageJava);
    });

    testWidgets('js files show languageJavascript icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('server.js'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageJavascript);
    });

    testWidgets('jsx files show languageJavascript icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('App.jsx'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageJavascript);
    });

    testWidgets('ts files show languageTypescript icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('tasks.ts'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageTypescript);
    });

    testWidgets('tsx files show languageTypescript icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('TodoApp.tsx'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageTypescript);
    });

    testWidgets('html files show languageHtml5 icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('index.html'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageHtml5);
    });

    testWidgets('css files show languageCss3 icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('app.css'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageCss3);
    });

    testWidgets('scss files show languageCss3 icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('styles.scss'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageCss3);
    });

    testWidgets('go files show languageGo icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('nearest.go'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageGo);
    });

    testWidgets('rs files show languageRust icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('matrix.rs'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageRust);
    });

    testWidgets('rb files show languageRuby icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('pipeline.rb'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageRuby);
    });

    testWidgets('swift files show languageSwift icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('cache.swift'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageSwift);
    });

    testWidgets('kt files show languageKotlin icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('users.kt'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageKotlin);
    });

    testWidgets('php files show languagePhp icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('query.php'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languagePhp);
    });

    testWidgets('lua files show languageLua icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('scheduler.lua'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageLua);
    });

    testWidgets('r files show languageR icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('analysis.r'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageR);
    });

    testWidgets('json files show codeJson icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('package.json'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.codeJson);
    });

    testWidgets('yaml files show fileCogOutline icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('config.yaml'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileCogOutline);
    });

    testWidgets('yml files show fileCogOutline icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('docker-compose.yml'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileCogOutline);
    });

    testWidgets('md files show languageMarkdown icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('README.md'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.languageMarkdown);
    });

    testWidgets('xml files show fileXmlBox icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('pom.xml'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileXmlBox);
    });

    testWidgets('sql files show database icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('schema.sql'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.database);
    });

    testWidgets('sh files show console icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('build.sh'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.console);
    });

    testWidgets('ps1 files show powershell icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('build.ps1'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.powershell);
    });

    testWidgets('Dockerfile shows docker icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('Dockerfile'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.docker);
    });

    testWidgets('.gitignore shows git icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('.gitignore'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.git);
    });

    testWidgets('lock files show lock icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('package.lock'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.lock);
    });

    testWidgets('png files show fileImageOutline icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('logo.png'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileImageOutline);
    });

    testWidgets('svg files show fileImageOutline icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('icon.svg'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileImageOutline);
    });

    testWidgets('zip files show zipBox icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('archive.zip'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.zipBox);
    });

    testWidgets('pdf files show filePdfBox icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('guide.pdf'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.filePdfBox);
    });

    testWidgets('exe files show applicationCog icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('app.exe'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.applicationCog);
    });

    testWidgets('dll files show applicationCog icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('runtime.dll'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.applicationCog);
    });

    testWidgets('unknown extension shows fileOutline icon', (tester) async {
      await tester.pumpWidget(buildFileIcon('data.xyz'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.fileOutline);
    });
  });

  // ── Folder icon mapping tests ───────────────────────────────────────
  group('FileIcon - folder icon mapping', () {
    Widget buildFolderIcon(String name, {bool expanded = false}) {
      return MaterialApp(
        home: Scaffold(
          body: FileIcon(name: name, isDirectory: true, isExpanded: expanded),
        ),
      );
    }

    testWidgets('src folder shows folderEditOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('src'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderEditOutline);
    });

    testWidgets('lib folder shows folderEditOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('lib'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderEditOutline);
    });

    testWidgets('test folder shows folderSearchOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('test'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderSearchOutline);
    });

    testWidgets('build folder shows folderCogOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('build'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderCogOutline);
    });

    testWidgets('docs folder shows folderTextOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('docs'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderTextOutline);
    });

    testWidgets('assets folder shows folderImage', (tester) async {
      await tester.pumpWidget(buildFolderIcon('assets'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderImage);
    });

    testWidgets('config folder shows folderCogOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('config'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderCogOutline);
    });

    testWidgets('node_modules folder shows folderLockOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('node_modules'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderLockOutline);
    });

    testWidgets('bin folder shows folderPlayOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('bin'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderPlayOutline);
    });

    testWidgets('web folder shows folderNetworkOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('web'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderNetworkOutline);
    });

    testWidgets('android folder shows folderStarOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('android'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderStarOutline);
    });

    testWidgets('ios folder shows folderStarOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('ios'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderStarOutline);
    });

    testWidgets('default folder shows folderOutline', (tester) async {
      await tester.pumpWidget(buildFolderIcon('my_folder'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderOutline);
    });

    testWidgets('expanded default folder shows folderOpenOutline', (
      tester,
    ) async {
      await tester.pumpWidget(buildFolderIcon('my_folder', expanded: true));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, MdiIcons.folderOpenOutline);
    });

    testWidgets('folder icons use warm gold color', (tester) async {
      await tester.pumpWidget(buildFolderIcon('src'));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFFCCAA66)); // _IconColors.folder
    });

    testWidgets('file icons use type-specific colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FileIcon(name: 'test.py'))),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFFCBB45E)); // _IconColors.gold (Python)
    });
  });

  group('FileIcon - theme switching', () {
    testWidgets('material icon theme changes file icon set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'script.py',
              themeMode: FileIconThemeMode.material,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.code);
    });

    testWidgets('cupertino icon theme changes folder icon set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'src',
              isDirectory: true,
              themeMode: FileIconThemeMode.cupertino,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, CupertinoIcons.folder);
    });

    testWidgets('vivid color theme applies vivid palette', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'script.py',
              colorTheme: FileIconColorTheme.vivid,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFFFFD54A));
    });

    testWidgets('font awesome theme changes file icon set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'guide.pdf',
              themeMode: FileIconThemeMode.fontAwesome,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, FontAwesomeIcons.filePdf);
    });

    testWidgets('phosphor theme changes file icon set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'schema.sql',
              themeMode: FileIconThemeMode.phosphor,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIcons.database());
    });

    testWidgets('monochrome color theme applies neutral folder color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileIcon(
              name: 'src',
              isDirectory: true,
              colorTheme: FileIconColorTheme.monochrome,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFF9A9A9A));
    });
  });
}
