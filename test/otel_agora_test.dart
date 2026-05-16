// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_agora/otel_agora.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_agora-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('RTC token records app + channel + video quality', () async {
    await tracedAgora<String>(
      service: 'rtc',
      operation: 'tokens.create',
      appId: 'app-abc',
      region: 'as-southeast',
      invoke: () async => const AgoraCallResult(
        value: 'ok',
        result: AgoraResult(
          channelName: 'session-42',
          uid: 8001,
          audioMinutes: 60,
          videoMinutes: 60,
          videoQuality: 'HD',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('agora rtc.tokens.create')!);
    expect(a['agora.app.id'], 'app-abc');
    expect(a['agora.channel.name'], 'session-42');
    expect(a['agora.video_quality'], 'HD');
    expect(a['cloud.region'], 'as-southeast');
  });

  test('recording start records recording id', () async {
    await tracedAgora<String>(
      service: 'recording',
      operation: 'start',
      invoke: () async => const AgoraCallResult(
        value: 'ok',
        result: AgoraResult(recordingId: 'rec-1'),
      ),
    );
    expect(
      attrsOf(
          spans.findSpanByName('agora recording.start')!)['agora.recording.id'],
      'rec-1',
    );
  });

  test('suppression skips spans', () async {
    await runWithoutAgoraInstrumentationAsync(() async {
      await tracedAgora<String>(
        service: 'rtc',
        operation: 'tokens.create',
        invoke: () async => const AgoraCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('agora '), isEmpty);
  });
}
