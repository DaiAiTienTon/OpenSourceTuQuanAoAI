import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';
import '../viewmodels/home_viewmodel.dart';

/// Cài thư viện: flutter pub add http
/// Đặt API key thực vào _apiKey (hoặc đọc từ env/config)
class AIRepositoryImpl implements AIRepository {
  static const _apiKey = 'YOUR_ANTHROPIC_API_KEY'; // thay bằng key thật
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-20250514';

  Future<String> _ask(String prompt) async {
    final res = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 500,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('AI API lỗi: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = json['content'] as List<dynamic>;
    return content
        .whereType<Map<String, dynamic>>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n');
  }

  @override
  Future<String> suggestOutfit({
    required List<ClothingItem> wardrobe,
    required String destination,
    required String health,
    required String weather,
  }) async {
    final tops = wardrobe.where((c) => c.category == 'tops').map((c) => c.name).join(', ');
    final bottoms = wardrobe.where((c) => c.category == 'bottoms').map((c) => c.name).join(', ');

    final prompt = '''
Bạn là trợ lý thời trang StyleAI. Hãy gợi ý một bộ trang phục phù hợp nhất dựa trên thông tin sau:
- Tủ áo: $tops
- Tủ quần/váy: $bottoms
- Địa điểm hôm nay: ${destination.isEmpty ? 'Không rõ' : destination}
- Tình trạng sức khoẻ: ${health.isEmpty ? 'Bình thường' : health}
- Thời tiết: ${weather.isEmpty ? 'Không có dữ liệu' : weather}

Hãy gợi ý 1 bộ cụ thể (áo + quần/váy) và giải thích ngắn gọn lý do (tối đa 100 từ, bằng tiếng Việt).
''';
    return _ask(prompt);
  }

  @override
  Future<String> evaluateOutfit({
    required ClothingItem top,
    required ClothingItem bottom,
    required String destination,
    required String health,
    required String weather,
  }) async {
    final prompt = '''
Bạn là trợ lý thời trang StyleAI. Hãy đánh giá bộ trang phục sau:
- Áo: ${top.name} ${top.desc.isNotEmpty ? '(${top.desc})' : ''}
- Quần/Váy: ${bottom.name} ${bottom.desc.isNotEmpty ? '(${bottom.desc})' : ''}
- Địa điểm: ${destination.isEmpty ? 'Không rõ' : destination}
- Tình trạng sức khoẻ: ${health.isEmpty ? 'Bình thường' : health}
- Thời tiết: ${weather.isEmpty ? 'Không có dữ liệu' : weather}

Cho điểm phù hợp (1-10) và nhận xét ngắn gọn về sự phối hợp màu sắc, phong cách, mức độ phù hợp với địa điểm và sức khoẻ (tối đa 120 từ, bằng tiếng Việt).
''';
    return _ask(prompt);
  }
}