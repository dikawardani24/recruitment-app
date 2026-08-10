import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import '../api/api_paths.dart';
import '../api/mappers.dart';
import '../api/response_models.dart';
import '../../domain/models.dart';

@Injectable()
class ChatApiDataSource {
  ChatApiDataSource(this._client);

  final ApiClient _client;

  Future<ChatResponseDto> ask({
    required String question,
    String? jobId,
    List<ChatMessage> history = const [],
    int topK = 10,
  }) {
    final data = <String, dynamic>{
      'question': question,
      'history': [
        for (final turn in history)
          {'role': turn.roleName, 'content': turn.content},
      ],
      'top_k': topK,
      'job_id': ?jobId,
    };
    return _client.post(
      ApiPaths.chat,
      data: data,
      parse: (resp) => ChatResponseMapper.fromJson(resp as Map<String, dynamic>),
    );
  }
}
