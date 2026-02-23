import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset/charset.dart' as charset;
import 'package:flutter/widgets.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../../core/services/app_log_service.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';
import 'terminal_settings_provider.dart';

enum TerminalProfileKind { cmd }

class TerminalProfile {
  const TerminalProfile({
    required this.id,
    required this.label,
    required this.kind,
    required this.executable,
    required this.args,
    this.environment,
  });

  final String id;
  final String label;
  final TerminalProfileKind kind;
  final String executable;
  final List<String> args;
  final Map<String, String>? environment;
}

class TerminalSessionView {
  const TerminalSessionView({
    required this.id,
    required this.name,
    required this.profileId,
    required this.output,
  });

  final String id;
  final String name;
  final String profileId;
  final String output;

  TerminalSessionView copyWith({
    String? id,
    String? name,
    String? profileId,
    String? output,
  }) {
    return TerminalSessionView(
      id: id ?? this.id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      output: output ?? this.output,
    );
  }
}

class TerminalState {
  const TerminalState({
    this.profiles = const [],
    this.sessions = const [],
    this.activeSessionId,
    this.selectedProfileId,
    this.errorMessage,
  });

  final List<TerminalProfile> profiles;
  final List<TerminalSessionView> sessions;
  final String? activeSessionId;
  final String? selectedProfileId;
  final String? errorMessage;

  TerminalState copyWith({
    List<TerminalProfile>? profiles,
    List<TerminalSessionView>? sessions,
    String? activeSessionId,
    String? selectedProfileId,
    String? errorMessage,
  }) {
    return TerminalState(
      profiles: profiles ?? this.profiles,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      errorMessage: errorMessage,
    );
  }
}

class _RuntimeSession {
  _RuntimeSession({
    required this.profile,
    required this.pty,
    required this.terminal,
    required this.outputSub,
  });

  final TerminalProfile profile;
  final Pty pty;
  final Terminal terminal;
  final StreamSubscription<Uint8List> outputSub;
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalNotifier(this.ref) : super(const TerminalState()) {
    _bootstrap();
  }

  final Ref ref;
  final Map<String, _RuntimeSession> _runtime = <String, _RuntimeSession>{};
  final Map<String, List<String>> _historyBySession = <String, List<String>>{};
  final Map<String, int> _historyCursorBySession = <String, int>{};
  final Map<String, String> _historyDraftBySession = <String, String>{};
  final Map<String, String> _inputBufferBySession = <String, String>{};
  final Set<String> _closingSessions = <String>{};
  int _idSeed = 0;
  static const int _maxOutputChars = 60000;
  static final RegExp _ansiPattern = RegExp(
    r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])',
  );

  Future<void> _bootstrap() async {
    final profiles = await _detectProfiles();
    if (!mounted) return;
    state = state.copyWith(
      profiles: profiles,
      selectedProfileId: profiles.isNotEmpty ? profiles.first.id : null,
    );
    if (profiles.isEmpty) {
      state = state.copyWith(errorMessage: 'No terminal profile detected.');
    }
  }

  /// Yields to the framework so the UI can render one frame before a heavy
  /// synchronous operation (e.g. Pty.start).
  static Future<void> _yieldFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<List<TerminalProfile>> _detectProfiles() async {
    return const [
      TerminalProfile(
        id: 'cmd',
        label: 'Command Prompt',
        kind: TerminalProfileKind.cmd,
        executable: 'cmd.exe',
        args: ['/Q', '/K'],
      ),
    ];
  }

  Future<void> refreshProfiles() async {
    final profiles = await _detectProfiles();
    if (!mounted) return;
    final selected = state.selectedProfileId;
    state = state.copyWith(
      profiles: profiles,
      selectedProfileId:
          profiles.any((p) => p.id == selected)
              ? selected
              : (profiles.isNotEmpty ? profiles.first.id : null),
    );
  }

  void setSelectedProfile(String profileId) {
    state = state.copyWith(selectedProfileId: profileId);
  }

  Future<void> createSession({String? profileId}) async {
    final profiles = state.profiles;
    if (profiles.isEmpty) return;
    final chosenId =
        profileId ??
        state.selectedProfileId ??
        ref.read(terminalSettingsProvider).defaultProfileId;
    final profile = profiles.firstWhere(
      (p) => p.id == chosenId,
      orElse: () => profiles.first,
    );
    final sessionId =
        'term_${DateTime.now().millisecondsSinceEpoch}_${_idSeed++}';
    final name = '${profile.label} ${state.sessions.length + 1}';

    state = state.copyWith(
      sessions: [
        ...state.sessions,
        TerminalSessionView(
          id: sessionId,
          name: name,
          profileId: profile.id,
          output: '',
        ),
      ],
      activeSessionId: sessionId,
      selectedProfileId: profile.id,
      errorMessage: null,
    );
    _historyBySession[sessionId] = <String>[];
    _historyCursorBySession[sessionId] = 0;
    _historyDraftBySession[sessionId] = '';
    _inputBufferBySession[sessionId] = '';

    final ok = await _spawnProcess(sessionId, profile);
    if (!ok) {
      closeSession(sessionId);
    }
  }

  /// Quote the executable path if it contains spaces, so that
  /// flutter_pty's unquoted command-line concatenation works with
  /// CreateProcessW (lpApplicationName = NULL).
  static String _quotedExe(String executable) {
    if (executable.contains(' ') && !executable.startsWith('"')) {
      return '"$executable"';
    }
    return executable;
  }

  Future<bool> _spawnProcess(String sessionId, TerminalProfile profile) async {
    try {
      // Yield a frame so the UI can render the new session tab before
      // the synchronous Pty.start blocks the event loop.
      await _yieldFrame();
      if (!mounted) return false;
      final cwd = ref.read(fileExplorerProvider).rootPath;
      final terminal = Terminal(maxLines: 10000);
      // Merge profile-specific env vars with system environment so the
      // child process retains PATH, SYSTEMROOT, etc.
      final env = profile.environment != null
          ? {...Platform.environment, ...profile.environment!}
          : null;
      final pty = Pty.start(
        _quotedExe(profile.executable),
        arguments: profile.args,
        workingDirectory: cwd,
        environment: env,
        rows: 28,
        columns: 120,
      );
      terminal.onOutput = (data) {
        pty.write(Uint8List.fromList(utf8.encode(data)));
      };
      terminal.onResize = (width, height, _, __) {
        pty.resize(height, width);
      };
      final outSub = pty.output.listen((chunk) {
        final text = _decodeOutput(chunk, profile: profile);
        terminal.write(text);
        _appendOutput(sessionId, text);
      });
      _runtime[sessionId] = _RuntimeSession(
        profile: profile,
        pty: pty,
        terminal: terminal,
        outputSub: outSub,
      );
      pty.exitCode.then((code) {
        if (_closingSessions.remove(sessionId)) return;
        if (code >= 0) {
          _appendOutput(sessionId, '\n[process exited: $code]\n');
          terminal.write('\r\n[process exited: $code]\r\n');
        }
      });
      _sendProfileInit(profile, pty);
      AppLogService.instance.info(
        'terminal',
        'sessionCreated id=$sessionId profile=${profile.id}',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      AppLogService.instance.error(
        'terminal',
        'sessionCreateFailed profile=${profile.id} error=$e',
      );
      return false;
    }
  }

  void _appendOutput(String sessionId, String chunk) {
    final sessions = [...state.sessions];
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    final clean = chunk.replaceAll(_ansiPattern, '');
    var merged = sessions[index].output + clean;
    if (merged.length > _maxOutputChars) {
      merged = merged.substring(merged.length - _maxOutputChars);
    }
    sessions[index] = sessions[index].copyWith(output: merged);
    state = state.copyWith(sessions: sessions);
  }

  void activateSession(String sessionId) {
    if (!state.sessions.any((s) => s.id == sessionId)) return;
    final session = state.sessions.where((s) => s.id == sessionId).first;
    state = state.copyWith(
      activeSessionId: sessionId,
      selectedProfileId: session.profileId,
    );
  }

  Future<void> closeSession(String sessionId) async {
    final runtime = _runtime.remove(sessionId);
    if (runtime != null) {
      _closingSessions.add(sessionId);
      await runtime.outputSub.cancel();
      runtime.pty.kill(ProcessSignal.sigterm);
      AppLogService.instance.info('terminal', 'sessionClosed id=$sessionId');
    }
    final sessions = state.sessions.where((s) => s.id != sessionId).toList();
    _historyBySession.remove(sessionId);
    _historyCursorBySession.remove(sessionId);
    _historyDraftBySession.remove(sessionId);
    _inputBufferBySession.remove(sessionId);
    String? nextActive = state.activeSessionId;
    if (nextActive == sessionId) {
      nextActive = sessions.isEmpty ? null : sessions.last.id;
    }
    state = state.copyWith(sessions: sessions, activeSessionId: nextActive);
  }

  void reorderSessions(int oldIndex, int newIndex) {
    final sessions = [...state.sessions];
    if (oldIndex < 0 || oldIndex >= sessions.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= sessions.length) return;
    final item = sessions.removeAt(oldIndex);
    sessions.insert(newIndex, item);
    state = state.copyWith(sessions: sessions);
  }

  Future<void> sendCommandToActive(String command) async {
    final activeId = state.activeSessionId;
    if (activeId == null || command.trim().isEmpty) return;
    final runtime = _runtime[activeId];
    if (runtime == null) return;
    _appendOutput(activeId, '\n\$ $command\n');
    _pushHistory(activeId, command);
    _inputBufferBySession[activeId] = '';
    runtime.pty.write(Uint8List.fromList(utf8.encode('$command\r\n')));
    AppLogService.instance.info(
      'terminal',
      'execute active=$activeId cmd=$command',
    );
  }

  Future<void> runInActiveTerminal(String command) =>
      sendCommandToActive(command);

  Future<void> sendRawToActive(String text) async {
    final activeId = state.activeSessionId;
    if (activeId == null || text.isEmpty) return;
    final runtime = _runtime[activeId];
    if (runtime == null) return;
    runtime.pty.write(Uint8List.fromList(utf8.encode(text)));
  }

  Future<void> sendEnterToActive() => sendRawToActive('\n');

  Future<void> sendBackspaceToActive() async {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    final runtime = _runtime[activeId];
    if (runtime == null) return;
    runtime.pty.write(Uint8List.fromList(const [8]));
  }

  Future<void> sendArrowUpToActive() => sendRawToActive('\x1b[A');

  Future<void> sendArrowDownToActive() => sendRawToActive('\x1b[B');

  void _pushHistory(String sessionId, String command) {
    final text = command.trim();
    if (text.isEmpty) return;
    final history = _historyBySession.putIfAbsent(sessionId, () => <String>[]);
    if (history.isEmpty || history.last != text) {
      history.add(text);
      if (history.length > 500) {
        history.removeRange(0, history.length - 500);
      }
    }
    _historyCursorBySession[sessionId] = history.length;
    _historyDraftBySession[sessionId] = '';
  }

  String recallHistoryUp(String sessionId, String currentInput) {
    final history = _historyBySession[sessionId] ?? const <String>[];
    if (history.isEmpty) return currentInput;
    final cursor = _historyCursorBySession[sessionId] ?? history.length;
    if (cursor == history.length) {
      _historyDraftBySession[sessionId] = currentInput;
    }
    final next = (cursor - 1).clamp(0, history.length - 1);
    _historyCursorBySession[sessionId] = next;
    return history[next];
  }

  String recallHistoryDown(String sessionId, String currentInput) {
    final history = _historyBySession[sessionId] ?? const <String>[];
    if (history.isEmpty) return currentInput;
    final cursor = _historyCursorBySession[sessionId] ?? history.length;
    final next = (cursor + 1).clamp(0, history.length);
    _historyCursorBySession[sessionId] = next;
    if (next >= history.length) {
      return _historyDraftBySession[sessionId] ?? '';
    }
    return history[next];
  }

  String getInputBuffer(String sessionId) =>
      _inputBufferBySession[sessionId] ?? '';

  void setInputBuffer(String sessionId, String value) {
    _inputBufferBySession[sessionId] = value;
    state = state.copyWith();
  }

  void appendInputChar(String sessionId, String char) {
    if (char.isEmpty) return;
    final current = _inputBufferBySession[sessionId] ?? '';
    _inputBufferBySession[sessionId] = '$current$char';
    state = state.copyWith();
  }

  void backspaceInput(String sessionId) {
    final current = _inputBufferBySession[sessionId] ?? '';
    if (current.isEmpty) return;
    _inputBufferBySession[sessionId] = current.substring(0, current.length - 1);
    state = state.copyWith();
  }

  void clearActiveOutput() {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    final sessions = [...state.sessions];
    final index = sessions.indexWhere((s) => s.id == activeId);
    if (index == -1) return;
    sessions[index] = sessions[index].copyWith(output: '');
    state = state.copyWith(sessions: sessions);
    final runtime = _runtime[activeId];
    runtime?.terminal.write('\x1b[2J\x1b[3J\x1b[H');
    AppLogService.instance.info('terminal', 'clearOutput session=$activeId');
  }

  Future<void> sendCtrlCToActive() async {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    final runtime = _runtime[activeId];
    if (runtime == null) return;
    try {
      runtime.pty.write(Uint8List.fromList(const [3]));
    } catch (_) {
      try {
        runtime.pty.kill(ProcessSignal.sigint);
      } catch (_) {}
    }
    _appendOutput(activeId, '\n^C\n');
    AppLogService.instance.info('terminal', 'ctrlC session=$activeId');
  }

  Future<void> restartActiveSession() async {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    final session = state.sessions.where((s) => s.id == activeId).firstOrNull;
    if (session == null) return;
    final profileId = session.profileId;
    await closeSession(activeId);
    await createSession(profileId: profileId);
    AppLogService.instance.info('terminal', 'restartSession old=$activeId');
  }

  String _decodeOutput(List<int> bytes, {required TerminalProfile profile}) {
    try {
      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (!utf8Text.contains('�')) return utf8Text;
      return charset.gbk.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  Terminal? terminalForSession(String sessionId) =>
      _runtime[sessionId]?.terminal;

  String outputForSession(String sessionId) {
    return state.sessions.where((s) => s.id == sessionId).firstOrNull?.output ??
        '';
  }

  void _sendProfileInit(TerminalProfile profile, Pty pty) {
    if (profile.kind == TerminalProfileKind.cmd) {
      pty.write(Uint8List.fromList(utf8.encode('chcp 65001\r\n')));
    }
  }

  @override
  void dispose() {
    for (final session in _runtime.values) {
      session.outputSub.cancel();
      session.pty.kill(ProcessSignal.sigterm);
    }
    _runtime.clear();
    super.dispose();
  }
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(ref),
);
