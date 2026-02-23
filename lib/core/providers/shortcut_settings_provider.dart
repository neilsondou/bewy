import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shortcut_binding.dart';
import '../services/config_service.dart';

enum ShortcutAction {
  undo,
  redo,
  cut,
  copy,
  paste,
  selectAll,
  toggleWordWrap,
  duplicateLineUp,
  duplicateLineDown,
  toggleSidebar,
  togglePanel,
  toggleEditor,
  toggleMinimap,
  save,
  saveAs,
  newFile,
  closeTab,
  openFile,
  nextTab,
  previousTab,
  find,
  replace,
  findInFiles,
  replaceInFiles,
  formatDocument,
  goToLine,
  zoomIn,
  zoomOut,
  resetZoom,
  showCodeActions,
  signatureHelp,
}

class ShortcutSettingsNotifier
    extends StateNotifier<Map<ShortcutAction, ShortcutBinding>> {
  ShortcutSettingsNotifier() : super(_defaultBindings()) {
    _load();
  }

  static Map<ShortcutAction, ShortcutBinding> _defaultBindings() {
    return {
      ShortcutAction.undo: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyZ',
      ),
      ShortcutAction.redo: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyY',
      ),
      ShortcutAction.cut: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyX',
      ),
      ShortcutAction.copy: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyC',
      ),
      ShortcutAction.paste: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyV',
      ),
      ShortcutAction.selectAll: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyA',
      ),
      ShortcutAction.toggleWordWrap: const ShortcutBinding(
        primary: false,
        alt: true,
        shift: false,
        keyId: 'KeyZ',
      ),
      ShortcutAction.duplicateLineUp: const ShortcutBinding(
        primary: false,
        alt: true,
        shift: true,
        keyId: 'ArrowUp',
      ),
      ShortcutAction.duplicateLineDown: const ShortcutBinding(
        primary: false,
        alt: true,
        shift: true,
        keyId: 'ArrowDown',
      ),
      ShortcutAction.toggleSidebar: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyB',
      ),
      ShortcutAction.togglePanel: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyJ',
      ),
      ShortcutAction.toggleEditor: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyE',
      ),
      ShortcutAction.toggleMinimap: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyM',
      ),
      ShortcutAction.save: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyS',
      ),
      ShortcutAction.saveAs: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyS',
      ),
      ShortcutAction.newFile: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyN',
      ),
      ShortcutAction.closeTab: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyW',
      ),
      ShortcutAction.openFile: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyO',
      ),
      ShortcutAction.nextTab: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'Tab',
      ),
      ShortcutAction.previousTab: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'Tab',
      ),
      ShortcutAction.find: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyF',
      ),
      ShortcutAction.replace: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyH',
      ),
      ShortcutAction.findInFiles: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyF',
      ),
      ShortcutAction.replaceInFiles: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyH',
      ),
      ShortcutAction.formatDocument: const ShortcutBinding(
        primary: false,
        alt: true,
        shift: true,
        keyId: 'KeyF',
      ),
      ShortcutAction.goToLine: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyG',
      ),
      ShortcutAction.zoomIn: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'Equal',
      ),
      ShortcutAction.zoomOut: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'Minus',
      ),
      ShortcutAction.resetZoom: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'Digit0',
      ),
      ShortcutAction.showCodeActions: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'Period',
      ),
      ShortcutAction.signatureHelp: const ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'Slash',
      ),
    };
  }

  Future<void> _load() async {
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      final raw = data['shortcuts'];
      if (raw is! Map) return;
      final next = {...state};
      for (final action in ShortcutAction.values) {
        final json = raw[action.name];
        if (json is Map<String, dynamic>) {
          next[action] = ShortcutBinding.fromJson(json);
        } else if (json is Map) {
          next[action] = ShortcutBinding.fromJson(
            json.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      }
      state = next;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['shortcuts'] = {
      for (final entry in state.entries) entry.key.name: entry.value.toJson(),
    };
    await ConfigService.save(data);
  }

  Map<String, dynamic> exportAsJsonMap() {
    return {
      for (final entry in state.entries) entry.key.name: entry.value.toJson(),
    };
  }

  bool importFromJsonMap(Map<String, dynamic> raw) {
    final next = <ShortcutAction, ShortcutBinding>{};
    for (final action in ShortcutAction.values) {
      final json = raw[action.name];
      if (json is Map<String, dynamic>) {
        next[action] = ShortcutBinding.fromJson(json);
      } else if (json is Map) {
        next[action] = ShortcutBinding.fromJson(
          json.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        next[action] = _defaultBindings()[action]!;
      }
    }

    final seen = <ShortcutBinding>{};
    for (final binding in next.values) {
      if (_isReservedBySystem(binding) || seen.contains(binding)) {
        return false;
      }
      seen.add(binding);
    }

    state = next;
    _persist();
    return true;
  }

  void resetToDefaults() {
    state = _defaultBindings();
    _persist();
  }

  bool setBinding(ShortcutAction action, ShortcutBinding binding) {
    if (_isReservedBySystem(binding)) {
      return false;
    }
    for (final entry in state.entries) {
      if (entry.key != action && entry.value == binding) {
        return false;
      }
    }
    state = {...state, action: binding};
    _persist();
    return true;
  }

  ShortcutBinding bindingOf(ShortcutAction action) => state[action]!;

  bool matches(ShortcutAction action, KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final binding = state[action];
    if (binding == null) return false;
    final ctrlPressed = HardwareKeyboard.instance.isControlPressed;
    final metaPressed = HardwareKeyboard.instance.isMetaPressed;
    final altPressed = HardwareKeyboard.instance.isAltPressed;
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
    return binding.matchesKeyDown(
      event: event,
      isMac: Platform.isMacOS,
      ctrlPressed: ctrlPressed,
      metaPressed: metaPressed,
      altPressed: altPressed,
      shiftPressed: shiftPressed,
    );
  }

  static bool _isReservedBySystem(ShortcutBinding binding) {
    // Keep app close / browser refresh combos unavailable.
    if (binding.primary &&
        !binding.alt &&
        !binding.shift &&
        binding.keyId == 'KeyQ') {
      return true;
    }
    if (binding.primary &&
        !binding.alt &&
        !binding.shift &&
        binding.keyId == 'KeyR') {
      return true;
    }
    return false;
  }
}

final shortcutSettingsProvider = StateNotifierProvider<
  ShortcutSettingsNotifier,
  Map<ShortcutAction, ShortcutBinding>
>((ref) => ShortcutSettingsNotifier());
