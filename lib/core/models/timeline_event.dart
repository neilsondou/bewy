enum TimelineEventType {
  saved,
  moved,
  renamed,
  deleted,
  createdFile,
  createdFolder,
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.type,
    required this.fileName,
    required this.filePath,
    required this.timestamp,
    this.beforeContent,
  });

  final String id;
  final TimelineEventType type;
  final String fileName;
  final String filePath;
  final DateTime timestamp;
  final String? beforeContent;

  Map<String, dynamic> toPayload() {
    return {
      'id': id,
      'type': type.name,
      'fileName': fileName,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'beforeContent': beforeContent,
    };
  }

  static TimelineEvent? fromPayload(Map<String, dynamic> payload) {
    final id = payload['id'] as String?;
    final typeRaw = payload['type'] as String?;
    final fileName = payload['fileName'] as String?;
    final filePath = payload['filePath'] as String?;
    final ts = payload['timestamp'] as String?;
    if (id == null ||
        typeRaw == null ||
        fileName == null ||
        filePath == null ||
        ts == null) {
      return null;
    }
    final type =
        TimelineEventType.values.where((e) => e.name == typeRaw).firstOrNull;
    final parsed = DateTime.tryParse(ts);
    if (type == null || parsed == null) return null;
    return TimelineEvent(
      id: id,
      type: type,
      fileName: fileName,
      filePath: filePath,
      timestamp: parsed,
      beforeContent: payload['beforeContent'] as String?,
    );
  }
}
