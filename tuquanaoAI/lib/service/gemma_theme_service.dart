import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llamadart/llamadart.dart';
import 'package:tuquanapai/core/app_dynamic_theme.dart';

enum GemmaStatus { idle, initializing, ready, inferring, error }

// ── ModelConfig ──────────────────────────────────────────────────────────────
//
// KHÔNG còn danh sách model hard-code. Thay vào đó, danh sách model có sẵn
// được QUÉT TỰ ĐỘNG từ 2 nguồn lúc runtime:
//   1. assets/models/*.gguf — bất kỳ file .gguf nào bạn bỏ vào thư mục này
//      và khai báo trong pubspec.yaml (dạng khai báo thư mục, xem note bên
//      dưới) sẽ tự xuất hiện, không cần sửa code.
//   2. <app documents>/imported_models/*.gguf — model bạn import từ máy
//      (vd model tự fine-tune) qua ModelConfig.importFromDevicePath(...).
//      File được copy vào đây nên sẽ được nhớ lại ở lần mở app sau, tự động
//      xuất hiện lại trong danh sách mà không cần import lại.
//
// Dùng ModelConfig.discoverAll() để lấy danh sách model hiện có.
//
// LƯU Ý pubspec.yaml: để AssetManifest liệt kê được toàn bộ file trong thư
// mục, khai báo cả thư mục thay vì từng file:
//   flutter:
//     assets:
//       - assets/models/
class ModelConfig {
  final String id; // key ngắn gọn, suy ra từ tên file
  final String displayName;
  final String assetPath; // đường dẫn trong assets/ (rỗng nếu dùng localPath)
  final String fileName; // tên file khi copy ra local storage / hoặc localPath nếu isLocalPath
  final int contextSize;

  const ModelConfig({
    required this.id,
    required this.displayName,
    required this.assetPath,
    required this.fileName,
    this.contextSize = 256,
  });

  /// Dùng khi model đã có sẵn file .gguf trên máy (đã được copy vào thư mục
  /// imported_models/ của app), không cần copy từ assets nữa.
  factory ModelConfig.fromLocalPath({
    required String id,
    required String displayName,
    required String localPath,
    int contextSize = 256,
  }) {
    return ModelConfig(
      id: id,
      displayName: displayName,
      assetPath: '', // rỗng => đánh dấu isLocalPath
      fileName: localPath,
      contextSize: contextSize,
    );
  }

  bool get isLocalPath => assetPath.isEmpty;

  static String _idFromFileName(String fileName) => fileName
      .replaceAll(RegExp(r'\.gguf$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  // ── Quét model đóng gói sẵn trong assets/models/ ───────────────────────
  static Future<List<ModelConfig>> _discoverAssetModels() async {
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();

      final gguf = allAssets.where((path) =>
      path.startsWith('assets/models/') &&
          path.toLowerCase().endsWith('.gguf'));

      return gguf.map((path) {
        final fileName = path.split('/').last;
        return ModelConfig(
          id: _idFromFileName(fileName),
          displayName: fileName,
          assetPath: path,
          fileName: fileName,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ModelConfig] ⚠️ Không đọc được AssetManifest: $e');
      return [];
    }
  }

  /// Thư mục lưu các model import từ máy — file được copy vào đây nên tồn
  /// tại lâu dài giữa các lần mở app, không cần import lại mỗi lần.
  static Future<Directory> _importedModelsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/imported_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Quét model đã import trước đó ───────────────────────────────────────
  static Future<List<ModelConfig>> _discoverImportedModels() async {
    try {
      final dir = await _importedModelsDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.gguf'));

      return files.map((f) {
        final fileName = f.path.split(Platform.pathSeparator).last;
        return ModelConfig.fromLocalPath(
          id: 'custom-${_idFromFileName(fileName)}',
          displayName: '📥 $fileName',
          localPath: f.path,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ModelConfig] ⚠️ Không quét được imported_models/: $e');
      return [];
    }
  }

  /// Copy 1 file .gguf từ đường dẫn bất kỳ trên máy (vd kết quả từ
  /// file_picker) vào thư mục imported_models/ của app, để nó được
  /// discoverAll() tìm thấy ở mọi lần chạy sau — không cần import lại.
  static Future<ModelConfig> importFromDevicePath(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final fileName = sourcePath.split(Platform.pathSeparator).last;
    final dir = await _importedModelsDir();
    final destPath = '${dir.path}/$fileName';

    if (sourcePath != destPath) {
      await sourceFile.copy(destPath);
    }

    return ModelConfig.fromLocalPath(
      id: 'custom-${_idFromFileName(fileName)}',
      displayName: '📥 $fileName',
      localPath: destPath,
    );
  }

  /// Quét TOÀN BỘ model hiện có (assets + imported), gọi lúc runtime — đây
  /// là danh sách "thư viện" model thật sự đang có, không phải danh sách
  /// cứng khai báo trước.
  static Future<List<ModelConfig>> discoverAll() async {
    final assets = await _discoverAssetModels();
    final imported = await _discoverImportedModels();
    return [...assets, ...imported];
  }
}

// ── ThemeContext ─────────────────────────────────────────────────────────────

class ThemeContext {
  const ThemeContext({
    required this.hourOfDay,
    this.tempC,
    this.weatherCondition,
    this.heartRateBpm,
    this.sleepHours,
    this.favoriteColor,
    this.wardrobeItemCount = 0,
    this.userName,
    this.userAge,
    this.userHobbies = const [],
  });

  final int hourOfDay;
  final double? tempC;
  final String? weatherCondition;
  final double? heartRateBpm;
  final double? sleepHours;
  final String? favoriteColor;
  final int wardrobeItemCount;
  final String? userName;
  final int? userAge;
  final List<String> userHobbies;

  /// Chuỗi ASCII ngắn gọn cho prompt — không có emoji, không có tiếng Việt
  String toPromptContext() {
    return [
      'time:${_timeLabel(hourOfDay)}',
      if (tempC != null) 'temp:${tempC!.round()}C',
      if (weatherCondition != null)
        'weather:${_sanitize(weatherCondition!)}',
      if (heartRateBpm != null) 'hr:${heartRateBpm!.round()}',
      if (sleepHours != null) 'sleep:${sleepHours!.round()}h',
      if (favoriteColor != null && favoriteColor!.isNotEmpty)
        'color:${_sanitize(favoriteColor!)}',
      if (userAge != null && userAge! > 0) 'age:$userAge',
      if (userHobbies.isNotEmpty)
        'hobbies:${_sanitizeHobbies(userHobbies)}',
    ].join(',');
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

  static String _sanitizeHobbies(List<String> hobbies) {
    const map = <String, String>{
      'yoga': 'yoga',
      'music': 'music',
      'nhac': 'music',
      'photo': 'photo',
      'anh': 'photo',
      'sport': 'sport',
      'the thao': 'sport',
      'outdoor': 'outdoor',
      'travel': 'travel',
      'du lich': 'travel',
      'art': 'art',
      'dance': 'dance',
      'cook': 'cook',
      'nau': 'cook',
      'read': 'read',
      'sach': 'read',
      'pet': 'pet',
      'thu': 'pet',
      'plant': 'plant',
      'cay': 'plant',
      'game': 'game',
    };

    final result = <String>{};
    for (final hobby in hobbies) {
      if (result.length >= 3) break;
      final normalized = hobby
          .toLowerCase()
          .replaceAll(RegExp(r'[^\x20-\x7Ea-z0-9 ]'), ' ')
          .trim();

      bool matched = false;
      for (final entry in map.entries) {
        if (normalized.contains(entry.key)) {
          result.add(entry.value);
          matched = true;
          break;
        }
      }
      if (!matched) {
        final ascii = _sanitize(hobby);
        if (ascii.length >= 2) {
          result.add(ascii.length > 6 ? ascii.substring(0, 6) : ascii);
        }
      }
    }
    return result.isEmpty ? '' : result.join('+');
  }

  static String _timeLabel(int h) => switch (h) {
    < 6 => 'night',
    < 12 => 'morning',
    < 17 => 'afternoon',
    < 20 => 'evening',
    _ => 'night',
  };
}

// ── BenchmarkResult ──────────────────────────────────────────────────────────

class ThemeBenchmark {
  final int promptChars;
  final int promptTokensEst;
  final int outputTokens;
  final int timeToFirstTokenMs;
  final int totalInferenceMs;
  final int initTimeMs;
  final String paletteName;
  final String rawOutput;
  final String modelId;

  const ThemeBenchmark({
    required this.promptChars,
    required this.promptTokensEst,
    required this.outputTokens,
    required this.timeToFirstTokenMs,
    required this.totalInferenceMs,
    required this.initTimeMs,
    required this.paletteName,
    required this.rawOutput,
    this.modelId = '',
  });

  double get tokensPerSecond => outputTokens > 0 && totalInferenceMs > 0
      ? (outputTokens * 1000) / totalInferenceMs
      : 0;

  void printReport() {
    debugPrint('');
    debugPrint('[BENCHMARK] ╔══════════════════════════════════════╗');
    debugPrint('[BENCHMARK] ║       THEME AI PERFORMANCE REPORT    ║');
    debugPrint('[BENCHMARK] ╠══════════════════════════════════════╣');
    if (modelId.isNotEmpty) {
      debugPrint('[BENCHMARK] ║ Model        : $modelId'.padRight(42) + '║');
    }
    if (initTimeMs > 0) {
      debugPrint(
          '[BENCHMARK] ║ Model init   : ${initTimeMs}ms'.padRight(42) + '║');
    }
    debugPrint('[BENCHMARK] ║ Prompt       : $promptChars chars (~$promptTokensEst tokens)'.padRight(42) + '║');
    debugPrint(
        '[BENCHMARK] ║ Time to 1st  : ${timeToFirstTokenMs}ms'.padRight(42) +
            '║');
    debugPrint(
        '[BENCHMARK] ║ Total infer  : ${totalInferenceMs}ms'.padRight(42) + '║');
    debugPrint(
        '[BENCHMARK] ║ Output tokens: $outputTokens'.padRight(42) + '║');
    debugPrint('[BENCHMARK] ║ Speed        : ${tokensPerSecond.toStringAsFixed(2)} tok/s'.padRight(42) + '║');
    debugPrint(
        '[BENCHMARK] ║ Palette      : $paletteName'.padRight(42) + '║');
    debugPrint(
        '[BENCHMARK] ║ Raw output   : "$rawOutput"'.padRight(42) + '║');
    debugPrint('[BENCHMARK] ╚══════════════════════════════════════╝');
    debugPrint('');
  }
}

// ── GemmaThemeService ────────────────────────────────────────────────────────

class GemmaThemeService extends ChangeNotifier {
  GemmaThemeService._();
  static final GemmaThemeService instance = GemmaThemeService._();

  GemmaStatus _status = GemmaStatus.idle;
  String? _errorMessage;

  /// Kết quả benchmark lần inference gần nhất — dùng để hiển thị UI hoặc log
  ThemeBenchmark? lastBenchmark;

  // LlamaEngine thay thế cho InferenceModel của thư viện cũ
  LlamaEngine? _engine;

  /// Model đang được load hiện tại. Không còn giá trị mặc định cứng — nếu
  /// initialize() được gọi mà không chỉ định model, service sẽ tự
  /// ModelConfig.discoverAll() và lấy model ĐẦU TIÊN tìm thấy trong "thư
  /// viện" (assets/models/ rồi tới imported_models/).
  ModelConfig? _currentModel;
  ModelConfig? get currentModel => _currentModel;

  GemmaStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isReady => _status == GemmaStatus.ready;

  // ── Khởi tạo model ───────────────────────────────────────────────────────

  /// Helper copy file model từ assets vào bộ nhớ tạm để llamadart đọc.
  /// Tên file cache giờ phụ thuộc vào ModelConfig.fileName, nên đổi model
  /// sẽ tự sinh ra file cache riêng, không bị đè lẫn nhau.
  Future<String> _extractModelFromAssets(String assetPath, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    if (!await file.exists()) {
      debugPrint('[ThemeAI] Đang copy model "$fileName" từ assets ra bộ nhớ trong...');
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
      );
    }
    return file.path;
  }

  Future<String> _resolveModelPath(ModelConfig model) async {
    if (model.isLocalPath) {
      // fileName ở đây chính là đường dẫn tuyệt đối tới file .gguf local
      return model.fileName;
    }
    return _extractModelFromAssets(model.assetPath, model.fileName);
  }

  /// [model] không truyền => tự ModelConfig.discoverAll() và lấy model đầu
  /// tiên tìm được trong "thư viện" hiện có (assets/models/ + đã import).
  /// Muốn đổi model chỉ cần gọi:
  ///   GemmaThemeService.instance.initialize(model: mySelectedModel);
  /// hoặc dùng switchModel() nếu app đã đang chạy với 1 model khác.
  Future<void> initialize({ModelConfig? model}) async {
    if (model != null) _currentModel = model;

    if (_currentModel == null) {
      final available = await ModelConfig.discoverAll();
      if (available.isEmpty) {
        _errorMessage =
        'Không tìm thấy model .gguf nào trong assets/models/ hoặc imported_models/.';
        _setStatus(GemmaStatus.error);
        debugPrint('[ThemeAI] ❌ ${_errorMessage}');
        return;
      }
      _currentModel = available.first;
      debugPrint('[ThemeAI] 🔍 Tự chọn model đầu tiên tìm thấy: ${_currentModel!.id}');
    }

    if (isReady) return;
    _setStatus(GemmaStatus.initializing);

    final initStart = DateTime.now();

    try {
      // 1. Khởi tạo engine với native backend
      _engine = LlamaEngine(LlamaBackend());

      // 2. Lấy đường dẫn model theo config hiện tại (assets hoặc local)
      final String modelPath = await _resolveModelPath(_currentModel!);

      // 3. Load model với Context Params theo config (ép RAM khi cần)
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: _currentModel!.contextSize,
        ),
      );

      final initMs = DateTime.now().difference(initStart).inMilliseconds;
      debugPrint('[ThemeAI] ✅ llamadart ready | model=${_currentModel!.id} | '
          'init=${initMs}ms | contextSize=${_currentModel!.contextSize}');

      _setStatus(GemmaStatus.ready);
    } catch (e, st) {
      _errorMessage = e.toString();
      _setStatus(GemmaStatus.error);
      debugPrint('[ThemeAI] ❌ Init error: $e\n$st');
    }
  }

  /// Đổi sang model khác lúc runtime: dispose engine cũ rồi load lại model
  /// mới. Dùng cái này khi app đang chạy (vd người dùng chọn model trong
  /// màn hình Settings) thay vì phải sửa code + build lại.
  Future<void> switchModel(ModelConfig model) async {
    if (_currentModel != null && model.id == _currentModel!.id && isReady) return;

    debugPrint('[ThemeAI] 🔄 Đổi model: ${_currentModel?.id ?? "(chưa có)"} → ${model.id}');
    _engine?.dispose();
    _engine = null;
    _currentModel = model;
    _setStatus(GemmaStatus.idle);
    await initialize(model: model);
  }

  // Luôn giải phóng tài nguyên
  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  // ── Sinh theme + đo benchmark (Áp dụng GBNF) ────────────────────────────
  Future<AppDynamicTheme?> generateTheme(ThemeContext ctx) async {
    if (!isReady || _engine == null) return null;
    _setStatus(GemmaStatus.inferring);

    final inferenceStart = DateTime.now();
    int timeToFirstTokenMs = -1;
    int tokenCount = 0;
    final buffer = StringBuffer();

    try {
      final rawPrompt = _buildPrompt(ctx);

      final prompt =
          '<|im_start|>system\n'
          'You are a helpful AI assistant <|im_end|>\n'
          '<|im_start|>user\n'
          '$rawPrompt<|im_end|>\n'
          '<|im_start|>assistant\n';

      final promptChars = prompt.length;
      final promptTokensEst = (promptChars / 4).ceil();

      debugPrint('[ThemeAI] ══════════════════════════════════════');
      debugPrint('[ThemeAI] MODEL  : ${_currentModel?.id}');
      debugPrint('[ThemeAI] CTX    : ${ctx.toPromptContext()}');
      debugPrint('[ThemeAI] PROMPT : $promptChars chars (~$promptTokensEst tokens)');
      debugPrint('[ThemeAI] ── Inference start ───────────────────');

      // GBNF grammar giữ nguyên, không đổi
      final String grammar = r'''
root ::= "{\"palette\": \"" palette-value "\"}"
palette-value ::= "ocean" | "forest" | "sunset" | "warm_orange" | "dark_blue" | "lavender" | "mint" | "rose" | "golden_morning" | "rainy_evening"
''';

      final stream = _engine!.generate(
        prompt,
        params: GenerationParams(
          maxTokens: 15,
          grammar: grammar,
        ),
      );

      // ... phần còn lại giữ nguyên y hệt

      final streamStart = DateTime.now();

      await for (final token in stream) {
        if (tokenCount == 0) {
          timeToFirstTokenMs =
              DateTime.now().difference(streamStart).inMilliseconds;
        }

        buffer.write(token);
        tokenCount++;

        debugPrint(
          '[ThemeAI] token[$tokenCount] '
              '(+${DateTime.now().difference(streamStart).inMilliseconds}ms): '
              '"$token"',
        );
      }

      final totalMs =
          DateTime.now().difference(inferenceStart).inMilliseconds;
      final rawOutput = buffer.toString().trim();

      // 3. Parse thẳng chuỗi output bằng JSON Decode siêu tốc
      final theme = _parseThemeFast(rawOutput);

      // Lưu benchmark
      lastBenchmark = ThemeBenchmark(
        promptChars: promptChars,
        promptTokensEst: promptTokensEst,
        outputTokens: tokenCount,
        timeToFirstTokenMs: timeToFirstTokenMs,
        totalInferenceMs: totalMs,
        initTimeMs: 0,
        paletteName: theme.name,
        rawOutput: rawOutput,
        modelId: _currentModel?.id ?? '',
      );

      lastBenchmark!.printReport();

      _setStatus(GemmaStatus.ready);
      notifyListeners();
      return theme;

    } catch (e, st) {
      final totalMs =
          DateTime.now().difference(inferenceStart).inMilliseconds;
      debugPrint('[ThemeAI] ❌ Inference error sau ${totalMs}ms: $e');
      debugPrint('[ThemeAI] StackTrace: $st');
      _setStatus(GemmaStatus.ready);
      return null;
    }
  }

  // ── Prompt ───────────────────────────────────────────────────────────────
  String _buildPrompt(ThemeContext ctx) {
    return 'Ctx:${ctx.toPromptContext()}. '
        'Pick ONE:ocean,forest,sunset,warm_orange,'
        'dark_blue,lavender,mint,rose,golden_morning,rainy_evening. '
        'JSON only.';
  }

  // ── Parse output (Siêu tốc bằng GBNF) ────────────────────────────────────
  AppDynamicTheme _parseThemeFast(String raw) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(raw);
      final String paletteName = jsonMap['palette'];

      const keywordMap = <String, ThemePalette>{
        'ocean': ThemePalette.ocean,
        'forest': ThemePalette.forest,
        'sunset': ThemePalette.sunset,
        'warm_orange': ThemePalette.warmOrange,
        'dark_blue': ThemePalette.darkBlue,
        'lavender': ThemePalette.lavender,
        'mint': ThemePalette.mint,
        'rose': ThemePalette.rose,
        'golden_morning': ThemePalette.goldenMorning,
        'rainy_evening': ThemePalette.rainyEvening,
      };

      final palette = keywordMap[paletteName];
      if (palette != null) {
        debugPrint('[ThemeAI] ✅ GBNF Palette matched: ${palette.name}');
        return palette.theme;
      }
    } catch (e) {
      debugPrint('[ThemeAI] ⚠️ Lỗi Parse JSON (Dù có GBNF): $e - Raw: $raw');
    }

    debugPrint('[ThemeAI] ⚠️ Fallback về default theme do lỗi.');
    return AppDynamicTheme.defaultTheme;
  }

  void _setStatus(GemmaStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

}