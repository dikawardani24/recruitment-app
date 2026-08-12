import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/data/api/api_client.dart';
import 'package:ai_ats/data/api/chat_stream_events.dart';
import 'package:ai_ats/data/api/response_models.dart';
import 'package:ai_ats/data/data_sources/chat_api_data_source.dart';
import 'package:ai_ats/data/repositories/chat_repository_impl.dart';
import 'package:ai_ats/domain/models.dart';

class _FakeChatDataSource extends ChatApiDataSource {
  _FakeChatDataSource() : super(ApiClient(dio: Dio()));

  late ChatResponseDto askResponse;
  late List<ChatModelDto> modelsResponse;
  final streamEvents = <ChatStreamEventDto>[];

  @override
  Future<ChatResponseDto> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) async {
    return askResponse;
  }

  @override
  Stream<ChatStreamEventDto> askStream({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
    String? model,
  }) async* {
    for (final event in streamEvents) {
      yield event;
    }
  }

  @override
  Future<List<ChatModelDto>> getModels() async => modelsResponse;
}

ChatResponseDto _chatResponse() {
  return ChatResponseDto(
    configured: true,
    answer: 'Alice fits the Flutter role.',
    sources: [
      ChatSourceResponse(
        entityType: 'candidate',
        entityId: 'c1',
        jobId: 'j1',
        name: 'alice.pdf',
        section: 'summary',
        score: 0.9,
      ),
    ],
    cards: [
      ChatCardResponse(
        type: 'job',
        jobs: [
          JobResponse(
            jobId: 'j1',
            title: 'Flutter Dev',
            description: 'Build apps',
            status: 'open',
            createdAt: '2026-08-06T14:05:00',
            cvCount: 2,
          ),
        ],
        candidates: [
          CandidateResponse(
            cvId: 'c1',
            jobId: 'j1',
            fileName: 'alice.pdf',
            status: 'ranked',
            candidateName: 'Alice',
            overallScore: 0.9,
            bucket: 'strong_match',
            strengths: [],
            weaknesses: [],
            skillGaps: [],
            skills: [],
            certifications: [],
            rankedBy: 'llm',
          ),
        ],
      ),
    ],
    retrievalEnabled: true,
    retrievalCount: 4,
  );
}

void main() {
  test('ask maps the response DTO into domain types', () async {
    final source = _FakeChatDataSource()..askResponse = _chatResponse();
    final repo = ChatRepositoryImpl(source);

    final response = await repo.ask(question: 'Who fits?');

    expect(response.configured, isTrue);
    expect(response.answer, 'Alice fits the Flutter role.');
    expect(response.retrievalEnabled, isTrue);
    expect(response.retrievalCount, 4);

    final s = response.sources.single;
    expect(s.entityType, 'candidate');
    expect(s.entityId, 'c1');
    expect(s.jobId, 'j1');
    expect(s.name, 'alice.pdf');
    expect(s.section, 'summary');
    expect(s.score, 0.9);

    final card = response.cards.single;
    expect(card.isJobs, isTrue);
    final job = card.jobs.single;
    expect(job.id, 'j1');
    expect(job.title, 'Flutter Dev');
    expect(job.candidateCount, 2);
    final candidate = card.candidates.single;
    expect(candidate.candidateName, 'Alice');
    expect(candidate.overallScore, 0.9);
    expect(candidate.rankedBy, 'llm');
  });

  test('askStream maps every SSE event type in order', () async {
    final source = _FakeChatDataSource()
      ..streamEvents.addAll([
        const ChatStreamStartedDto(),
        const ChatStreamStatusDto(stage: 'routing', message: 'Understanding...'),
        const ChatStreamToolDto('search'),
        const ChatStreamTextDto('Alice'),
        ChatStreamDoneDto(_chatResponse()),
        const ChatStreamErrorDto('boom'),
      ]);
    final repo = ChatRepositoryImpl(source);

    final events = await repo.askStream(question: 'Who fits?').toList();

    expect(events, hasLength(6));
    expect(events[0], isA<ChatStreamStarted>());
    final status = events[1] as ChatStreamStatus;
    expect(status.stage, 'routing');
    expect(status.message, 'Understanding...');
    expect((events[2] as ChatStreamTool).name, 'search');
    expect((events[3] as ChatStreamText).content, 'Alice');
    expect((events[4] as ChatStreamDone).response.answer, 'Alice fits the Flutter role.');
    expect((events[5] as ChatStreamError).message, 'boom');
  });

  test('getModels maps each model DTO', () async {
    final source = _FakeChatDataSource()
      ..modelsResponse = [
        ChatModelDto(
          id: 'gpt-4o',
          label: 'GPT-4o',
          provider: 'openai',
          model: 'gpt-4o',
        ),
      ];
    final repo = ChatRepositoryImpl(source);

    final models = await repo.getModels();

    final model = models.single;
    expect(model.id, 'gpt-4o');
    expect(model.label, 'GPT-4o');
    expect(model.provider, 'openai');
    expect(model.model, 'gpt-4o');
  });
}
