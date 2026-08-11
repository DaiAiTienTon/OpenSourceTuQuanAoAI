// evaluation/lib/evaluation_dashboard.dart
//
// Màn hình tổng hợp kết quả thực nghiệm — dành cho debug / nghiên cứu.
// Thêm vào app bằng cách navigate đến EvaluationDashboard() từ một nút ẩn.
//
// Hiển thị:
//   - Bộ chọn model (model có sẵn HOẶC import file .gguf tuỳ ý từ máy,
//     vd model bạn tự fine-tune) cho phần 4.2 On-device benchmark
//   - Nút chạy từng phần / chạy tất cả
//   - Bảng kết quả từng metric
//   - Nút copy JSON để dán vào báo cáo
//
// LƯU Ý: cần thêm dependency `file_picker` vào pubspec.yaml:
//   dependencies:
//     file_picker: ^8.0.0

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart' show ModelConfig;
import 'evaluation_runner.dart';
import 'user_study_screen.dart';

class EvaluationDashboard extends StatefulWidget {
  const EvaluationDashboard({super.key});

  @override
  State<EvaluationDashboard> createState() => _EvaluationDashboardState();
}

class _EvaluationDashboardState extends State<EvaluationDashboard> {
  final EvaluationRunner _runner = EvaluationRunner();

  bool _onDevice = true;
  bool _cloud = true;
  bool _consistency = true;
  bool _ruleVsLlm = true;

  // ── Model được chọn cho phần 4.2 On-device ──────────────────────────────
  // Danh sách model KHÔNG còn hard-code — được quét động từ:
  //   assets/models/*.gguf  +  <app docs>/imported_models/*.gguf
  // qua ModelConfig.discoverAll(). Import model mới sẽ copy file vào
  // imported_models/ nên tồn tại lâu dài, tự xuất hiện lại ở lần mở app sau.
  List<ModelConfig> _availableModels = [];
  ModelConfig? _selectedModel; // null => chưa quét xong / chưa chọn
  bool _loadingModels = true;

  @override
  void initState() {
    super.initState();
    _runner.addListener(() => setState(() {}));
    _loadModelLibrary();
  }

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  Future<void> _loadModelLibrary() async {
    setState(() => _loadingModels = true);
    final models = await ModelConfig.discoverAll();
    if (!mounted) return;
    setState(() {
      _availableModels = models;
      // Giữ lựa chọn cũ nếu vẫn còn trong danh sách, không thì lấy cái đầu
      final stillExists = _selectedModel != null &&
          models.any((m) => m.id == _selectedModel!.id);
      if (!stillExists) {
        _selectedModel = models.isNotEmpty ? models.first : null;
      }
      _loadingModels = false;
    });
  }

  Future<void> _pickModelFromDevice() async {
    try {
      // FileType.custom + allowedExtensions: ['gguf'] bị file_picker trên
      // Android từ chối vì 'gguf' không có mime-type tương ứng. Dùng
      // FileType.any rồi tự lọc đuôi .gguf sau khi người dùng chọn.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;

      if (!path.toLowerCase().endsWith('.gguf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn file .gguf')),
          );
        }
        return;
      }

      // Copy vào imported_models/ của app => tồn tại lâu dài, tự động được
      // discoverAll() tìm thấy ở các lần mở app sau, không cần import lại.
      final imported = await ModelConfig.importFromDevicePath(path);

      // Quét lại toàn bộ thư viện để danh sách + lựa chọn luôn đồng bộ với
      // những gì thực sự có trên máy.
      await _loadModelLibrary();
      if (!mounted) return;
      setState(() => _selectedModel = imported);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã import model: ${imported.fileName.split(Platform.pathSeparator).last}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi import model: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Evaluation Dashboard'),
        backgroundColor: const Color(0xFF3A5FA8),
        foregroundColor: Colors.white,
        actions: [
          if (_runner.resultOnDevice != null ||
              _runner.resultCloud != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy JSON',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _runner.reportJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã copy JSON kết quả')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Model selector ───────────────────────────────────────
          _ModelSelector(
            models: _availableModels,
            selected: _selectedModel,
            isRunning: _runner.isRunning,
            isLoading: _loadingModels,
            onSelected: (m) => setState(() => _selectedModel = m),
            onImport: _pickModelFromDevice,
            onRefresh: _loadModelLibrary,
          ),

          // ── Control panel ─────────────────────────────────────────
          _ControlPanel(
            onDevice: _onDevice,
            cloud: _cloud,
            consistency: _consistency,
            ruleVsLlm: _ruleVsLlm,
            onChanged: (od, c, con, rv) => setState(() {
              _onDevice = od;
              _cloud = c;
              _consistency = con;
              _ruleVsLlm = rv;
            }),
            isRunning: _runner.isRunning,
            onRun: () => _runner.runAll(
              model: _selectedModel,
              runOnDevice: _onDevice,
              runCloud: _cloud,
              runConsistency: _consistency,
              runRuleVsLlm: _ruleVsLlm,
            ),
          ),

          // ── Results ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Log viewer
                  if (_runner.isRunning || _runner.logs.isNotEmpty)
                    _LogViewer(logs: _runner.logs, isRunning: _runner.isRunning),

                  if (_runner.resultOnDevice != null)
                    _ResultCard(
                      title: '4.2 On-Device'
                          '${_selectedModel != null ? " (${_selectedModel!.displayName})" : ""}',
                      icon: Icons.smartphone,
                      color: const Color(0xFF2E7D5E),
                      data: {
                        'Init time': '${_runner.resultOnDevice!['init_time_ms']}ms',
                        'TTFT (mean)': '${_runner.resultOnDevice!['ttft_mean_ms']}ms',
                        'TTFT (P95)': '${_runner.resultOnDevice!['ttft_p95_ms']}ms',
                        'TTFT cold': '${_runner.resultOnDevice!['ttft_cold_mean_ms']}ms',
                        'TTFT warm': '${_runner.resultOnDevice!['ttft_warm_mean_ms']}ms',
                        'Speed': '${_runner.resultOnDevice!['tok_per_sec_mean']} tok/s',
                        'Output tokens': '${_runner.resultOnDevice!['output_tokens_mean']} (avg)',
                        'Accuracy': '${_runner.resultOnDevice!['accuracy_pct']}%',
                        'Total inference': '${_runner.resultOnDevice!['total_inf_mean_ms']}ms',
                      },
                    ),

                  if (_runner.resultCloud != null)
                    _ResultCard(
                      title: '4.3 Cloud API (Llama 3.1 8B)',
                      icon: Icons.cloud,
                      color: const Color(0xFF3A5FA8),
                      data: {
                        'Latency (mean)': '${_runner.resultCloud!['latency_mean_ms']}ms',
                        'Latency (P50)': '${_runner.resultCloud!['latency_p50_ms']}ms',
                        'Latency (P95)': '${_runner.resultCloud!['latency_p95_ms']}ms',
                        'Availability': '${_runner.resultCloud!['availability_pct']}%',
                        'Timeout count': '${_runner.resultCloud!['timeout_count']}',
                        'Accuracy': '${_runner.resultCloud!['accuracy_pct']}%',
                        'Cost/request': '\$${_runner.resultCloud!['estimated_cost_per_request_usd']}',
                        'Privacy': 'Data gửi qua mạng',
                      },
                    ),

                  if (_runner.resultOnDevice != null && _runner.resultCloud != null)
                    _ComparisonCard(
                      onDevice: _runner.resultOnDevice!,
                      cloud: _runner.resultCloud!,
                    ),

                  if (_runner.resultConsistency != null)
                    _ResultCard(
                      title: '4.4 Consistency Test',
                      icon: Icons.loop,
                      color: const Color(0xFF8A5FD0),
                      data: {
                        'Consistency rate': '${_runner.resultConsistency!['consistency_rate_pct']}%',
                        'Cases tested': '${_runner.resultConsistency!['cases_tested']}',
                        'Runs per case': '${_runner.resultConsistency!['repeat_count_per_case']}',
                        'Consistent cases': '${_runner.resultConsistency!['consistent_cases']}',
                        'Inconsistent': '${_runner.resultConsistency!['inconsistent_cases']}',
                        'Threshold': '≥${_runner.resultConsistency!['consistency_threshold_pct']}%',
                      },
                    ),

                  if (_runner.resultRuleVsLlm != null)
                    _ResultCard(
                      title: '4.5 Rule-Based vs LLM',
                      icon: Icons.compare_arrows,
                      color: const Color(0xFFE8724A),
                      data: {
                        'Agreement rate': '${_runner.resultRuleVsLlm!['agreement_rate_pct']}%',
                        'Rule accuracy': '${_runner.resultRuleVsLlm!['rule_accuracy_pct']}%',
                        'LLM accuracy': '${_runner.resultRuleVsLlm!['llm_accuracy_pct']}%',
                        'Edge cases': '${_runner.resultRuleVsLlm!['edge_case_count']}',
                        'LLM wins': '${_runner.resultRuleVsLlm!['llm_wins_count']}',
                        'Rule wins': '${_runner.resultRuleVsLlm!['rule_wins_count']}',
                        'Both wrong': '${_runner.resultRuleVsLlm!['both_wrong_count']}',
                        'Rule latency': '${_runner.resultRuleVsLlm!['rule_latency_mean_ms']}ms',
                        'LLM latency': '${_runner.resultRuleVsLlm!['llm_latency_mean_ms']}ms',
                        'Speedup': '${_runner.resultRuleVsLlm!['latency_speedup_x']}x faster (rule)',
                      },
                    ),

                  // User study button
                  _UserStudySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ModelSelector extends StatelessWidget {
  final List<ModelConfig> models;
  final ModelConfig? selected;
  final bool isRunning;
  final bool isLoading;
  final ValueChanged<ModelConfig> onSelected;
  final VoidCallback onImport;
  final VoidCallback onRefresh;

  static const String _importValue = '__import__';

  const _ModelSelector({
    required this.models,
    required this.selected,
    required this.isRunning,
    required this.isLoading,
    required this.onSelected,
    required this.onImport,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Model (4.2 On-device) — quét từ thư viện:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            InkWell(
              onTap: isRunning || isLoading ? null : onRefresh,
              child: Icon(Icons.refresh,
                  size: 16,
                  color: isRunning || isLoading
                      ? Colors.grey[300]
                      : Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Đang quét model...', style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        else if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chưa có model .gguf nào (assets/models/ hoặc đã import).',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                TextButton.icon(
                  onPressed: isRunning ? null : onImport,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Import', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selected?.id,
                    items: [
                      ...models.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          m.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                      const DropdownMenuItem(
                        value: _importValue,
                        child: Text(
                          '➕ Import model từ máy (.gguf)...',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF3A5FA8)),
                        ),
                      ),
                    ],
                    onChanged: isRunning
                        ? null
                        : (value) {
                      if (value == _importValue) {
                        onImport();
                        return;
                      }
                      final m = models.firstWhere((m) => m.id == value);
                      onSelected(m);
                    },
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 6),
      ],
    ),
  );
}

class _ControlPanel extends StatelessWidget {
  final bool onDevice, cloud, consistency, ruleVsLlm, isRunning;
  final void Function(bool, bool, bool, bool) onChanged;
  final VoidCallback onRun;

  const _ControlPanel({
    required this.onDevice,
    required this.cloud,
    required this.consistency,
    required this.ruleVsLlm,
    required this.isRunning,
    required this.onChanged,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn phần đánh giá:',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            FilterChip(
              label: const Text('4.2 On-device'),
              selected: onDevice,
              onSelected: isRunning
                  ? null
                  : (v) => onChanged(v, cloud, consistency, ruleVsLlm),
            ),
            FilterChip(
              label: const Text('4.3 Cloud API'),
              selected: cloud,
              onSelected: isRunning
                  ? null
                  : (v) => onChanged(onDevice, v, consistency, ruleVsLlm),
            ),
            FilterChip(
              label: const Text('4.4 Consistency'),
              selected: consistency,
              onSelected: isRunning
                  ? null
                  : (v) => onChanged(onDevice, cloud, v, ruleVsLlm),
            ),
            FilterChip(
              label: const Text('4.5 Rule vs LLM'),
              selected: ruleVsLlm,
              onSelected: isRunning
                  ? null
                  : (v) => onChanged(onDevice, cloud, consistency, v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isRunning ? null : onRun,
            icon: isRunning
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.play_arrow),
            label: Text(isRunning ? 'Đang chạy...' : 'Chạy đánh giá'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A5FA8),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> data;

  const _ResultCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 14)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1),
            },
            children: data.entries
                .map((e) => TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(e.key,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(e.value,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]))
                .toList(),
          ),
        ),
      ],
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  final Map<String, dynamic> onDevice;
  final Map<String, dynamic> cloud;

  const _ComparisonCard({required this.onDevice, required this.cloud});

  @override
  Widget build(BuildContext context) {
    final latencyOnDevice = onDevice['total_inf_mean_ms'];
    final latencyCloud = cloud['latency_mean_ms'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8920A).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 So sánh trực tiếp',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          _CompRow('Latency',
              '${latencyOnDevice}ms (on-device)', '${latencyCloud}ms (cloud)'),
          _CompRow('Accuracy',
              '${onDevice['accuracy_pct']}%', '${cloud['accuracy_pct']}%'),
          _CompRow('Chi phí/request', '\$0.00', '\$${cloud['estimated_cost_per_request_usd']}'),
          _CompRow('Privacy', '✅ Data tại thiết bị', '⚠️ Data qua mạng'),
          _CompRow('Offline', '✅ Hoạt động 100%', '❌ Cần internet'),
        ],
      ),
    );
  }
}

class _CompRow extends StatelessWidget {
  final String label, left, right;
  const _CompRow(this.label, this.left, this.right);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
        Expanded(
            child: Text(left,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(
            child: Text(right,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

class _LogViewer extends StatelessWidget {
  final List<String> logs;
  final bool isRunning;

  const _LogViewer({required this.logs, required this.isRunning});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    height: 140,
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E2E),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (_, i) => Text(
        logs[i],
        style: const TextStyle(
          color: Color(0xFF90E0B0),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    ),
  );
}

class _UserStudySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF8A5FD0).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('4.6 User Study',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        const Text(
          'Gửi link màn hình này cho người dùng thực để thu thập đánh giá Likert.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final results =
                  await UserStudyResultsReader.loadAndAggregate();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('User Study Results'),
                        content: SingleChildScrollView(
                          child: Text(
                            const JsonEncoder.withIndent('  ')
                                .convert(results),
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              final json =
                              await UserStudyResultsReader.exportJson();
                              Clipboard.setData(
                                  ClipboardData(text: json));
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Copy JSON'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bar_chart, size: 16),
                label: const Text('Xem kết quả'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A5FD0),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}