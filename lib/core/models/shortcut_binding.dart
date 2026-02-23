import 'package:flutter/services.dart';

/// A user-configurable keyboard shortcut binding.
class ShortcutBinding {
  const ShortcutBinding({
    required this.primary,
    required this.alt,
    required this.shift,
    required this.keyId,
  });

  final bool primary;
  final bool alt;
  final bool shift;
  final String keyId;

  ShortcutBinding copyWith({
    bool? primary,
    bool? alt,
    bool? shift,
    String? keyId,
  }) {
    return ShortcutBinding(
      primary: primary ?? this.primary,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
      keyId: keyId ?? this.keyId,
    );
  }

  Map<String, dynamic> toJson() {
    return {'primary': primary, 'alt': alt, 'shift': shift, 'keyId': keyId};
  }

  factory ShortcutBinding.fromJson(Map<String, dynamic> json) {
    return ShortcutBinding(
      primary: json['primary'] as bool? ?? false,
      alt: json['alt'] as bool? ?? false,
      shift: json['shift'] as bool? ?? false,
      keyId: json['keyId'] as String? ?? 'KeyA',
    );
  }

  String displayLabel({required bool isMac}) {
    final parts = <String>[];
    if (primary) {
      parts.add(isMac ? 'Cmd' : 'Ctrl');
    }
    if (alt) {
      parts.add(isMac ? 'Option' : 'Alt');
    }
    if (shift) {
      parts.add('Shift');
    }
    parts.add(_displayKeyLabel(keyId));
    return parts.join('+');
  }

  bool matchesKeyDown({
    required KeyDownEvent event,
    required bool isMac,
    required bool ctrlPressed,
    required bool metaPressed,
    required bool altPressed,
    required bool shiftPressed,
  }) {
    final primaryPressed = isMac ? metaPressed : ctrlPressed;
    if (primary != primaryPressed) return false;
    if (!primary && (ctrlPressed || metaPressed)) return false;
    if (alt != altPressed) return false;
    if (shift != shiftPressed) return false;
    return event.logicalKey == keyIdToLogicalKey(keyId);
  }

  static LogicalKeyboardKey keyIdToLogicalKey(String keyId) {
    return _supportedKeys[keyId] ?? LogicalKeyboardKey.keyA;
  }

  static String _displayKeyLabel(String keyId) {
    switch (keyId) {
      case 'Equal':
        return '=';
      case 'Minus':
        return '-';
      case 'Digit0':
        return '0';
      case 'Slash':
        return '/';
      case 'Period':
        return '.';
      case 'Tab':
        return 'Tab';
      case 'ArrowUp':
        return 'Up';
      case 'ArrowDown':
        return 'Down';
      default:
        if (keyId.startsWith('Key') && keyId.length == 4) {
          return keyId.substring(3);
        }
        return keyId;
    }
  }

  static const Map<String, LogicalKeyboardKey> _supportedKeys = {
    'KeyA': LogicalKeyboardKey.keyA,
    'KeyB': LogicalKeyboardKey.keyB,
    'KeyC': LogicalKeyboardKey.keyC,
    'KeyD': LogicalKeyboardKey.keyD,
    'KeyE': LogicalKeyboardKey.keyE,
    'KeyF': LogicalKeyboardKey.keyF,
    'KeyG': LogicalKeyboardKey.keyG,
    'KeyH': LogicalKeyboardKey.keyH,
    'KeyI': LogicalKeyboardKey.keyI,
    'KeyJ': LogicalKeyboardKey.keyJ,
    'KeyK': LogicalKeyboardKey.keyK,
    'KeyL': LogicalKeyboardKey.keyL,
    'KeyM': LogicalKeyboardKey.keyM,
    'KeyN': LogicalKeyboardKey.keyN,
    'KeyO': LogicalKeyboardKey.keyO,
    'KeyP': LogicalKeyboardKey.keyP,
    'KeyQ': LogicalKeyboardKey.keyQ,
    'KeyR': LogicalKeyboardKey.keyR,
    'KeyS': LogicalKeyboardKey.keyS,
    'KeyT': LogicalKeyboardKey.keyT,
    'KeyU': LogicalKeyboardKey.keyU,
    'KeyV': LogicalKeyboardKey.keyV,
    'KeyW': LogicalKeyboardKey.keyW,
    'KeyX': LogicalKeyboardKey.keyX,
    'KeyY': LogicalKeyboardKey.keyY,
    'KeyZ': LogicalKeyboardKey.keyZ,
    'Tab': LogicalKeyboardKey.tab,
    'ArrowUp': LogicalKeyboardKey.arrowUp,
    'ArrowDown': LogicalKeyboardKey.arrowDown,
    'Equal': LogicalKeyboardKey.equal,
    'Minus': LogicalKeyboardKey.minus,
    'Digit0': LogicalKeyboardKey.digit0,
    'Slash': LogicalKeyboardKey.slash,
    'Period': LogicalKeyboardKey.period,
  };

  static List<String> supportedKeyIds() => _supportedKeys.keys.toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShortcutBinding &&
        other.primary == primary &&
        other.alt == alt &&
        other.shift == shift &&
        other.keyId == keyId;
  }

  @override
  int get hashCode => Object.hash(primary, alt, shift, keyId);
}
