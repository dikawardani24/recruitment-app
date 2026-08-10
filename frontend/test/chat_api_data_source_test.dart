import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/data/api/api_client.dart';
import 'package:ai_ats/data/api/chat_stream_events.dart';
import 'package:ai_ats/data/data_sources/chat_api_data_source.dart';
import 'package:ai_ats/domain/models.dart';

class _StreamAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(
      Stream.value(
        Uint8List.fromList(
          utf8.encode(
            'data: {"type":"done","configured":true,"answer":"Found a match.","sources":[],"retrieval":{"enabled":true,"count":0}}\n\n',
          ),
        ),
      ),
      200,
      headers: {
        'content-type': ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('streams chat using a JSON-encodable request body', () async {
    final adapter = _StreamAdapter();
    final client = ApiClient(dio: Dio()..httpClientAdapter = adapter);
    final source = ChatApiDataSource(client);

    final events = await source
        .askStream(
          question: 'Who fits the Flutter role?',
          history: const [
            ChatMessage(
              role: ChatRole.user,
              content: 'Show Flutter candidates',
            ),
          ],
        )
        .toList();

    expect(adapter.request!.data, {
      'question': 'Who fits the Flutter role?',
      'history': [
        {'role': 'user', 'content': 'Show Flutter candidates'},
      ],
      'top_k': 10,
    });
    expect(events.single, isA<ChatStreamDoneDto>());
    expect(
      (events.single as ChatStreamDoneDto).response.answer,
      'Found a match.',
    );
  });
}
