import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/providers/file_icon_theme_provider.dart';

class _MutedIconColors {
  _MutedIconColors._();

  static const Color folder = Color(0xFFCCAA66);
  static const Color blue = Color(0xFF6CA6CD);
  static const Color teal = Color(0xFF6BB8A8);
  static const Color gold = Color(0xFFCBB45E);
  static const Color orange = Color(0xFFCC9466);
  static const Color green = Color(0xFF88B888);
  static const Color purple = Color(0xFF9988C0);
  static const Color rose = Color(0xFFC08888);
  static const Color neutral = Color(0xFF888888);
}

class _VividIconColors {
  _VividIconColors._();

  static const Color folder = Color(0xFFFFC857);
  static const Color blue = Color(0xFF4D9FFF);
  static const Color teal = Color(0xFF00BFA6);
  static const Color gold = Color(0xFFFFD54A);
  static const Color orange = Color(0xFFFF8A3D);
  static const Color green = Color(0xFF66CC66);
  static const Color purple = Color(0xFFB57BFF);
  static const Color rose = Color(0xFFFF6FA8);
  static const Color neutral = Color(0xFFB0B0B0);
}

class _MonochromeIconColors {
  _MonochromeIconColors._();

  static const Color folder = Color(0xFF9A9A9A);
  static const Color neutral = Color(0xFF8A8A8A);
}

enum _FileCategory {
  blueFamily,
  goldFamily,
  orangeFamily,
  tealFamily,
  greenFamily,
  purpleFamily,
  roseFamily,
  neutralFamily,
}

class FileIcon extends StatelessWidget {
  const FileIcon({
    super.key,
    required this.name,
    this.isDirectory = false,
    this.isExpanded = false,
    this.themeMode = FileIconThemeMode.classic,
    this.colorTheme = FileIconColorTheme.muted,
  });

  final String name;
  final bool isDirectory;
  final bool isExpanded;
  final FileIconThemeMode themeMode;
  final FileIconColorTheme colorTheme;

  @override
  Widget build(BuildContext context) {
    final ext = _getExtension();
    if (isDirectory) {
      return Icon(
        _getFolderIcon(),
        size: LayoutConstants.fileTreeIconSize,
        color: _resolveColor(ext, isFolder: true),
      );
    }

    return Icon(
      _getFileIcon(ext),
      size: LayoutConstants.fileTreeIconSize,
      color: _resolveColor(ext),
    );
  }

  String _getExtension() {
    final lower = name.toLowerCase();
    if (lower == 'dockerfile') return 'dockerfile';
    if (lower == '.gitignore') return 'gitignore';
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  IconData _getFolderIcon() {
    final lower = name.toLowerCase();

    if (themeMode == FileIconThemeMode.material) {
      switch (lower) {
        case 'src':
        case 'lib':
        case 'source':
          return Icons.code;
        case 'test':
        case 'tests':
        case 'spec':
        case 'specs':
        case 'integration_test':
          return Icons.science;
        case 'build':
        case 'dist':
        case 'out':
        case 'output':
        case 'target':
          return Icons.build;
        case 'doc':
        case 'docs':
        case 'documentation':
          return Icons.description;
        case 'assets':
        case 'images':
        case 'img':
        case 'icons':
        case 'fonts':
        case 'resources':
        case 'res':
          return Icons.image;
        case 'config':
        case 'configs':
        case 'configuration':
        case 'settings':
          return Icons.settings;
        case 'node_modules':
        case '.dart_tool':
        case 'packages':
          return Icons.lock;
        case 'bin':
        case 'scripts':
        case 'tool':
        case 'tools':
          return Icons.play_arrow;
        case 'web':
        case 'www':
        case 'public':
        case 'static':
          return Icons.public;
        case 'android':
        case 'ios':
        case 'macos':
        case 'linux':
        case 'windows':
          return Icons.devices;
        default:
          return isExpanded ? Icons.folder_open : Icons.folder;
      }
    }

    if (themeMode == FileIconThemeMode.cupertino) {
      return isExpanded ? CupertinoIcons.folder_fill : CupertinoIcons.folder;
    }

    if (themeMode == FileIconThemeMode.fontAwesome) {
      return isExpanded ? FontAwesomeIcons.folderOpen : FontAwesomeIcons.folder;
    }

    if (themeMode == FileIconThemeMode.phosphor) {
      return isExpanded ? PhosphorIcons.folderOpen() : PhosphorIcons.folder();
    }

    switch (lower) {
      case 'src':
      case 'lib':
      case 'source':
        return MdiIcons.folderEditOutline;
      case 'test':
      case 'tests':
      case 'spec':
      case 'specs':
      case 'integration_test':
        return MdiIcons.folderSearchOutline;
      case 'build':
      case 'dist':
      case 'out':
      case 'output':
      case 'target':
        return MdiIcons.folderCogOutline;
      case 'doc':
      case 'docs':
      case 'documentation':
        return MdiIcons.folderTextOutline;
      case 'assets':
      case 'images':
      case 'img':
      case 'icons':
      case 'fonts':
      case 'resources':
      case 'res':
        return MdiIcons.folderImage;
      case 'config':
      case 'configs':
      case 'configuration':
      case 'settings':
        return MdiIcons.folderCogOutline;
      case 'node_modules':
      case '.dart_tool':
      case 'packages':
        return MdiIcons.folderLockOutline;
      case 'bin':
      case 'scripts':
      case 'tool':
      case 'tools':
        return MdiIcons.folderPlayOutline;
      case 'web':
      case 'www':
      case 'public':
      case 'static':
        return MdiIcons.folderNetworkOutline;
      case 'android':
      case 'ios':
      case 'macos':
      case 'linux':
      case 'windows':
        return MdiIcons.folderStarOutline;
      default:
        return isExpanded ? MdiIcons.folderOpenOutline : MdiIcons.folderOutline;
    }
  }

  IconData _getFileIcon(String ext) {
    if (themeMode == FileIconThemeMode.material) {
      switch (ext) {
        case 'dart':
          return Icons.flutter_dash;
        case 'py':
          return Icons.code;
        case 'c':
        case 'cpp':
        case 'cc':
        case 'cxx':
        case 'java':
        case 'js':
        case 'jsx':
        case 'ts':
        case 'tsx':
        case 'go':
        case 'rs':
        case 'rb':
        case 'swift':
        case 'kt':
        case 'kts':
        case 'php':
        case 'lua':
        case 'r':
          return Icons.code;
        case 'html':
        case 'css':
        case 'scss':
        case 'sass':
          return Icons.public;
        case 'json':
        case 'yaml':
        case 'yml':
        case 'xml':
          return Icons.settings;
        case 'md':
          return Icons.description;
        case 'sql':
          return Icons.storage;
        case 'sh':
        case 'bash':
        case 'zsh':
        case 'ps1':
          return Icons.code;
        case 'dockerfile':
          return Icons.inventory_2;
        case 'gitignore':
          return Icons.account_tree;
        case 'lock':
          return Icons.lock;
        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'gif':
        case 'svg':
        case 'ico':
        case 'webp':
          return Icons.image;
        case 'zip':
        case 'tar':
        case 'gz':
        case 'rar':
        case '7z':
          return Icons.archive;
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'exe':
        case 'dll':
          return Icons.settings_applications;
        default:
          return Icons.insert_drive_file;
      }
    }

    if (themeMode == FileIconThemeMode.cupertino) {
      switch (ext) {
        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'gif':
        case 'svg':
        case 'ico':
        case 'webp':
          return CupertinoIcons.photo;
        case 'zip':
        case 'tar':
        case 'gz':
        case 'rar':
        case '7z':
          return CupertinoIcons.archivebox;
        case 'pdf':
          return CupertinoIcons.doc_text;
        case 'exe':
        case 'dll':
          return CupertinoIcons.gear_alt;
        default:
          return CupertinoIcons.doc;
      }
    }

    if (themeMode == FileIconThemeMode.fontAwesome) {
      switch (ext) {
        case 'dart':
        case 'py':
        case 'c':
        case 'cpp':
        case 'cc':
        case 'cxx':
        case 'java':
        case 'js':
        case 'jsx':
        case 'ts':
        case 'tsx':
        case 'go':
        case 'rs':
        case 'rb':
        case 'swift':
        case 'kt':
        case 'kts':
        case 'php':
        case 'lua':
        case 'r':
          return FontAwesomeIcons.code;
        case 'html':
        case 'css':
        case 'scss':
        case 'sass':
          return FontAwesomeIcons.globe;
        case 'json':
        case 'yaml':
        case 'yml':
        case 'xml':
          return FontAwesomeIcons.gear;
        case 'md':
          return FontAwesomeIcons.fileLines;
        case 'sql':
          return FontAwesomeIcons.database;
        case 'sh':
        case 'bash':
        case 'zsh':
        case 'ps1':
          return FontAwesomeIcons.terminal;
        case 'dockerfile':
          return FontAwesomeIcons.boxArchive;
        case 'gitignore':
          return FontAwesomeIcons.codeBranch;
        case 'lock':
          return FontAwesomeIcons.lock;
        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'gif':
        case 'svg':
        case 'ico':
        case 'webp':
          return FontAwesomeIcons.fileImage;
        case 'zip':
        case 'tar':
        case 'gz':
        case 'rar':
        case '7z':
          return FontAwesomeIcons.fileZipper;
        case 'pdf':
          return FontAwesomeIcons.filePdf;
        case 'exe':
        case 'dll':
          return FontAwesomeIcons.gears;
        default:
          return FontAwesomeIcons.file;
      }
    }

    if (themeMode == FileIconThemeMode.phosphor) {
      switch (ext) {
        case 'dart':
        case 'py':
        case 'c':
        case 'cpp':
        case 'cc':
        case 'cxx':
        case 'java':
        case 'js':
        case 'jsx':
        case 'ts':
        case 'tsx':
        case 'go':
        case 'rs':
        case 'rb':
        case 'swift':
        case 'kt':
        case 'kts':
        case 'php':
        case 'lua':
        case 'r':
          return PhosphorIcons.code();
        case 'html':
        case 'css':
        case 'scss':
        case 'sass':
          return PhosphorIcons.globe();
        case 'json':
        case 'yaml':
        case 'yml':
        case 'xml':
          return PhosphorIcons.sliders();
        case 'md':
          return PhosphorIcons.fileText();
        case 'sql':
          return PhosphorIcons.database();
        case 'sh':
        case 'bash':
        case 'zsh':
        case 'ps1':
          return PhosphorIcons.terminal();
        case 'dockerfile':
          return PhosphorIcons.package();
        case 'gitignore':
          return PhosphorIcons.gitBranch();
        case 'lock':
          return PhosphorIcons.lock();
        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'gif':
        case 'svg':
        case 'ico':
        case 'webp':
          return PhosphorIcons.image();
        case 'zip':
        case 'tar':
        case 'gz':
        case 'rar':
        case '7z':
          return PhosphorIcons.fileArchive();
        case 'pdf':
          return PhosphorIcons.filePdf();
        case 'exe':
        case 'dll':
          return PhosphorIcons.gear();
        default:
          return PhosphorIcons.file();
      }
    }

    switch (ext) {
      case 'dart':
        return Icons.flutter_dash;
      case 'py':
        return MdiIcons.languagePython;
      case 'c':
        return MdiIcons.languageC;
      case 'cpp':
      case 'cc':
      case 'cxx':
        return MdiIcons.languageCpp;
      case 'java':
        return MdiIcons.languageJava;
      case 'js':
      case 'jsx':
        return MdiIcons.languageJavascript;
      case 'ts':
      case 'tsx':
        return MdiIcons.languageTypescript;
      case 'html':
        return MdiIcons.languageHtml5;
      case 'css':
      case 'scss':
      case 'sass':
        return MdiIcons.languageCss3;
      case 'go':
        return MdiIcons.languageGo;
      case 'rs':
        return MdiIcons.languageRust;
      case 'rb':
        return MdiIcons.languageRuby;
      case 'swift':
        return MdiIcons.languageSwift;
      case 'kt':
      case 'kts':
        return MdiIcons.languageKotlin;
      case 'php':
        return MdiIcons.languagePhp;
      case 'lua':
        return MdiIcons.languageLua;
      case 'r':
        return MdiIcons.languageR;
      case 'json':
        return MdiIcons.codeJson;
      case 'yaml':
      case 'yml':
        return MdiIcons.fileCogOutline;
      case 'md':
        return MdiIcons.languageMarkdown;
      case 'xml':
        return MdiIcons.fileXmlBox;
      case 'sql':
        return MdiIcons.database;
      case 'sh':
      case 'bash':
      case 'zsh':
        return MdiIcons.console;
      case 'ps1':
        return MdiIcons.powershell;
      case 'dockerfile':
        return MdiIcons.docker;
      case 'gitignore':
        return MdiIcons.git;
      case 'lock':
        return MdiIcons.lock;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'ico':
      case 'webp':
        return MdiIcons.fileImageOutline;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
        return MdiIcons.zipBox;
      case 'pdf':
        return MdiIcons.filePdfBox;
      case 'exe':
      case 'dll':
        return MdiIcons.applicationCog;
      default:
        return MdiIcons.fileOutline;
    }
  }

  _FileCategory _category(String ext) {
    switch (ext) {
      case 'dart':
      case 'ts':
      case 'tsx':
      case 'c':
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'lua':
      case 'r':
      case 'sql':
      case 'ps1':
      case 'md':
        return _FileCategory.blueFamily;

      case 'py':
      case 'js':
      case 'jsx':
        return _FileCategory.goldFamily;

      case 'java':
      case 'swift':
      case 'rs':
      case 'html':
      case 'gitignore':
        return _FileCategory.orangeFamily;

      case 'go':
      case 'dockerfile':
        return _FileCategory.tealFamily;

      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'sh':
      case 'bash':
      case 'zsh':
        return _FileCategory.greenFamily;

      case 'css':
      case 'scss':
      case 'sass':
      case 'kt':
      case 'kts':
      case 'php':
        return _FileCategory.purpleFamily;

      case 'rb':
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'ico':
      case 'webp':
      case 'pdf':
        return _FileCategory.roseFamily;

      case 'lock':
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
      case 'exe':
      case 'dll':
        return _FileCategory.neutralFamily;

      default:
        return _FileCategory.neutralFamily;
    }
  }

  Color _resolveColor(String ext, {bool isFolder = false}) {
    switch (colorTheme) {
      case FileIconColorTheme.vivid:
        if (isFolder) return _VividIconColors.folder;
        return _resolveCategoryColor(_category(ext), vivid: true);
      case FileIconColorTheme.monochrome:
        return isFolder
            ? _MonochromeIconColors.folder
            : _MonochromeIconColors.neutral;
      case FileIconColorTheme.muted:
        if (isFolder) return _MutedIconColors.folder;
        return _resolveCategoryColor(_category(ext), vivid: false);
    }
  }

  Color _resolveCategoryColor(_FileCategory category, {required bool vivid}) {
    switch (category) {
      case _FileCategory.blueFamily:
        return vivid ? _VividIconColors.blue : _MutedIconColors.blue;
      case _FileCategory.goldFamily:
        return vivid ? _VividIconColors.gold : _MutedIconColors.gold;
      case _FileCategory.orangeFamily:
        return vivid ? _VividIconColors.orange : _MutedIconColors.orange;
      case _FileCategory.tealFamily:
        return vivid ? _VividIconColors.teal : _MutedIconColors.teal;
      case _FileCategory.greenFamily:
        return vivid ? _VividIconColors.green : _MutedIconColors.green;
      case _FileCategory.purpleFamily:
        return vivid ? _VividIconColors.purple : _MutedIconColors.purple;
      case _FileCategory.roseFamily:
        return vivid ? _VividIconColors.rose : _MutedIconColors.rose;
      case _FileCategory.neutralFamily:
        return vivid ? _VividIconColors.neutral : _MutedIconColors.neutral;
    }
  }
}
