import 'package:flutter/services.dart';

import '../models/shared_fit_draft.dart';
import '../models/shared_fit_event.dart';

class ShareIntakeService {
  static const String malformedPayloadMessage =
      'Unable to read shared FIT file';

  ShareIntakeService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methodChannel =
          methodChannel ??
          const MethodChannel('onelap_strava_sync/share_intake'),
      _eventChannel =
          eventChannel ??
          const EventChannel('onelap_strava_sync/shared_fit_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Future<SharedFitEvent?> loadInitialEvent() async {
    final dynamic payload = await _methodChannel.invokeMethod<Object?>(
      'getInitialSharedFit',
    );
    if (payload == null) {
      return null;
    }
    return _toEvent(payload);
  }

  Stream<SharedFitEvent> get events {
    return _eventChannel.receiveBroadcastStream().map(_toEvent);
  }

  SharedFitEvent _toEvent(dynamic payload) {
    if (payload is! Map<Object?, Object?>) {
      return const SharedFitEvent.error(malformedPayloadMessage);
    }
    final Map<Object?, Object?> values = payload;

    final Object? messageValue = values['message'];
    if (messageValue is String && messageValue.isNotEmpty) {
      return SharedFitEvent.error(messageValue);
    }

    final Object? localFilePathValue = values['localFilePath'];
    final Object? displayNameValue = values['displayName'];
    if (localFilePathValue is! String || localFilePathValue.isEmpty) {
      return const SharedFitEvent.error(malformedPayloadMessage);
    }
    if (displayNameValue is! String || displayNameValue.isEmpty) {
      return const SharedFitEvent.error(malformedPayloadMessage);
    }

    return SharedFitEvent.draft(
      SharedFitDraft(
        localFilePath: localFilePathValue,
        displayName: displayNameValue,
      ),
    );
  }
}
