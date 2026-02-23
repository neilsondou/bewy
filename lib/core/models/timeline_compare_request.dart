class TimelineCompareRequest {
  const TimelineCompareRequest({
    required this.currentTabId,
    required this.snapshotTabId,
  });

  final String currentTabId;
  final String snapshotTabId;
}
