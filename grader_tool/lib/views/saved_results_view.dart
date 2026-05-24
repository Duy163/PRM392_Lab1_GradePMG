import 'package:flutter/material.dart';
import 'package:grader_tool/services/result_storage_service.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class SavedResultsView extends StatefulWidget {
  const SavedResultsView({super.key});

  @override
  State<SavedResultsView> createState() => _SavedResultsViewState();
}

class _SavedResultsViewState extends State<SavedResultsView> {
  List<FileSystemEntity> _resultFiles = [];
  bool _isLoading = false;
  int _daysToDelete = 30;

  @override
  void initState() {
    super.initState();
    _loadResultFiles();
  }

  Future<void> _loadResultFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final files = await ResultStorageService.getAllResultFiles();
      if (!mounted) return;
      setState(() {
        _resultFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Lỗi load files: $e')));
      }
    }
  }

  Future<void> _deleteOldFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          _daysToDelete == 0
              ? 'Bạn có chắc muốn xóa toàn bộ file kết quả đã lưu?'
              : 'Bạn có chắc muốn xóa tất cả file kết quả cũ hơn $_daysToDelete ngày?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final deletedCount = await ResultStorageService.deleteOldResults(
        olderThanDays: _daysToDelete,
      );
      await _loadResultFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _daysToDelete == 0
                  ? '✅ Đã xóa toàn bộ file kết quả'
                  : '✅ Đã xóa $deletedCount file cũ',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa file này?\n\n${filePath.split(Platform.pathSeparator).last}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ResultStorageService.deleteResultFile(filePath);
      if (success) {
        await _loadResultFiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Đã xóa file')));
        }
      }
    }
  }

  Future<void> _viewFileDetails(String filePath) async {
    final data = await ResultStorageService.loadResultFromFile(filePath);
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Không thể đọc file')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chi tiết kết quả chấm điểm',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        'Sinh viên',
                        data['metadata']['student_file'],
                      ),
                      _buildInfoRow(
                        'Thời gian chấm',
                        _formatDateTime(data['metadata']['graded_at']),
                      ),
                      _buildInfoRow(
                        'Khóa học',
                        data['metadata']['rubric_course'],
                      ),
                      _buildInfoRow(
                        'Tiêu đề',
                        data['metadata']['rubric_title'],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Kết quả',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Tổng điểm',
                        '${data['summary']['total_score']} / ${data['metadata']['total_possible_points']}',
                      ),
                      _buildInfoRow(
                        'Phần trăm',
                        '${data['summary']['percentage']}%',
                      ),
                      _buildInfoRow(
                        'Số yêu cầu',
                        '${data['summary']['requirements_count']}',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nhận xét chung',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(data['summary']['general_feedback']),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chi tiết từng yêu cầu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...((data['grading_result']['requirements'] as List).map((
                        req,
                      ) {
                        final criteria = (req['criteria'] as List?) ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              childrenPadding: const EdgeInsets.all(16),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${req['requirement_id']}: ${req['requirement_name']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Điểm: ${req['subtotal_score']} / ${req['max_score']}',
                                    style: TextStyle(
                                      color: _getScoreColor(
                                        context,
                                        req['subtotal_score'],
                                        req['max_score'],
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                if (criteria.isEmpty)
                                  const Text('Không có chi tiết tiêu chí')
                                else
                                  ...criteria.map((crit) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  crit['criterion_name'] ??
                                                      crit['criterion_id'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getLevelColor(
                                                    context,
                                                    crit['level_awarded'],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${crit['score_given']} / ${crit['max_score']}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (crit['feedback'] != null &&
                                              crit['feedback']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '💬 ${crit['feedback']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _getScoreColor(BuildContext context, dynamic score, dynamic maxScore) {
    final s = (score is num) ? score.toDouble() : 0.0;
    final m = (maxScore is num) ? maxScore.toDouble() : 1.0;
    final ratio = m > 0 ? s / m : 0.0;

    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Color _getLevelColor(BuildContext context, String? level) {
    switch (level) {
      case 'full':
        return Colors.green.withAlpha((0.2 * 255).round());
      case 'partial':
        return Colors.orange.withAlpha((0.2 * 255).round());
      case 'fail':
        return Colors.red.withAlpha((0.2 * 255).round());
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kết quả đã lưu',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý các file kết quả chấm điểm đã lưu',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _loadResultFiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Làm mới'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _resultFiles.isNotEmpty
                        ? () => _showDeleteDialog()
                        : null,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Xóa file cũ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_resultFiles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có file kết quả nào được lưu',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  itemCount: _resultFiles.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = _resultFiles[index];
                    final stat = file.statSync();
                    final fileName = file.path
                        .split(Platform.pathSeparator)
                        .last;
                    final modifiedDate = DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(stat.modified);
                    final fileSize = _formatFileSize(stat.size);

                    return ListTile(
                      leading: Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(fileName),
                      subtitle: Text('$modifiedDate • $fileSize'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _viewFileDetails(file.path),
                            icon: const Icon(Icons.visibility),
                            tooltip: 'Xem chi tiết',
                          ),
                          IconButton(
                            onPressed: () => _deleteFile(file.path),
                            icon: const Icon(Icons.delete),
                            tooltip: 'Xóa',
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa file cũ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xóa tất cả file kết quả cũ hơn:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _daysToDelete,
              decoration: const InputDecoration(
                labelText: 'Số ngày',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Xóa tất cả (bao gồm hôm nay)')),
                DropdownMenuItem(value: 7, child: Text('7 ngày')),
                DropdownMenuItem(value: 14, child: Text('14 ngày')),
                DropdownMenuItem(value: 30, child: Text('30 ngày')),
                DropdownMenuItem(value: 60, child: Text('60 ngày')),
                DropdownMenuItem(value: 90, child: Text('90 ngày')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _daysToDelete = value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOldFiles();
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
