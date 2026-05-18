// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_agora_suppression.dart';

const _tracerName = 'dartastic_otel_libs_agora';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AgoraResult {
  const AgoraResult({
    this.channelName,
    this.uid,
    this.recordingId,
    this.audioMinutes,
    this.videoMinutes,
    this.videoQuality,
    this.statusCode,
  });

  /// `cname` (channel name) — Agora's multi-tenant unit within an app.
  final String? channelName;

  /// User id within the channel.
  final int? uid;

  /// `resourceId`/`sid` pair for cloud recording.
  final String? recordingId;

  /// Audio aggregate participant-minutes for the call.
  final int? audioMinutes;
  final int? videoMinutes;

  /// `SD` / `HD` / `HD+` / `Full HD` / `2K` / `4K` — Agora bills the
  /// minute counter at different rates per tier.
  final String? videoQuality;
  final int? statusCode;
}

class AgoraCallResult<T> {
  const AgoraCallResult({required this.value, this.result});
  final T value;
  final AgoraResult? result;
}

/// Wraps an Agora REST API call (token, recording, RTM, channel mgmt)
/// in a CLIENT span. [service] is `rtc`, `rtm`, `recording`,
/// `streaming`, `conversation_ai`. [operation] is the route key.
Future<T> tracedAgora<T>({
  required String service,
  required String operation,
  required Future<AgoraCallResult<T>> Function() invoke,
  String? appId,
  String? region,
}) async {
  if (agoraInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'agora',
    'rpc.method': operation,
    'agora.service': service,
  };
  if (appId != null) m['agora.app.id'] = appId;
  if (region != null) m['cloud.region'] = region;

  final span = _tracer().startSpan(
    'agora $service.$operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.channelName != null) {
        extras.add(OTel.attributeString(
          'agora.channel.name',
          r.result!.channelName!,
        ));
      }
      if (r.result!.uid != null) {
        extras.add(OTel.attributeInt('agora.uid', r.result!.uid!));
      }
      if (r.result!.recordingId != null) {
        extras.add(OTel.attributeString(
          'agora.recording.id',
          r.result!.recordingId!,
        ));
      }
      if (r.result!.audioMinutes != null) {
        extras.add(OTel.attributeInt(
          'agora.audio_minutes',
          r.result!.audioMinutes!,
        ));
      }
      if (r.result!.videoMinutes != null) {
        extras.add(OTel.attributeInt(
          'agora.video_minutes',
          r.result!.videoMinutes!,
        ));
      }
      if (r.result!.videoQuality != null) {
        extras.add(OTel.attributeString(
          'agora.video_quality',
          r.result!.videoQuality!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Agora status ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
