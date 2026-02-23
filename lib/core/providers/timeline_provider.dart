import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timeline_compare_request.dart';
import '../models/timeline_event.dart';

class TimelineState {
  const TimelineState({this.events = const []});

  final List<TimelineEvent> events;

  TimelineState copyWith({List<TimelineEvent>? events}) {
    return TimelineState(events: events ?? this.events);
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier() : super(const TimelineState());

  static const int _maxEvents = 500;

  void add(TimelineEvent event) {
    final next = [event, ...state.events];
    if (next.length > _maxEvents) {
      next.removeRange(_maxEvents, next.length);
    }
    state = state.copyWith(events: next);
  }

  void addFromPayload(Map<String, dynamic> payload) {
    final event = TimelineEvent.fromPayload(payload);
    if (event == null) return;
    add(event);
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>(
  (ref) => TimelineNotifier(),
);

final timelineCompareRequestProvider = StateProvider<TimelineCompareRequest?>(
  (ref) => null,
);
