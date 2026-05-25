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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Container(
          width: 1100,
          height: 720,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF0EA5E9), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết kết quả chấm điểm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            data['metadata']['student_file'] ?? 'Sinh viên',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                            children: [
                              const TextSpan(text: 'Score: '),
                              TextSpan(
                                text: '${data['summary']['total_score']}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              TextSpan(text: ' / ${data['metadata']['total_possible_points']}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Result metadata overview & general feedback
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng quan bài chấm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow(isDark, 'Sinh viên', data['metadata']['student_file']),
                                        _buildInfoRow(isDark, 'Thời gian chấm', _formatDateTime(data['metadata']['graded_at'])),
                                        _buildInfoRow(isDark, 'Khóa học', data['metadata']['rubric_course']),
                                        _buildInfoRow(isDark, 'Yêu cầu đề bài', data['metadata']['rubric_title']),
                                        _buildInfoRow(isDark, 'Số yêu cầu', '${data['summary']['requirements_count']}'),
                                        _buildInfoRow(isDark, 'Phần trăm đạt', '${data['summary']['percentage']}%'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Nhận xét chung',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF6366F1).withOpacity(0.15),
                                      ),
                                    ),
                                    child: Text(
                                      data['summary']['general_feedback'] ?? 'Không có nhận xét chung.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.6,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: Rubric scoring expand list
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết điểm theo Rubric',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: (data['grading_result']['requirements'] as List).length,
                              itemBuilder: (context, qIndex) {
                                final req = data['grading_result']['requirements'][qIndex];
                                final criteria = (req['criteria'] as List?) ?? [];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: true,
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      childrenPadding: const EdgeInsets.all(16),
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${req['requirement_id']}: ${req['requirement_name']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getScoreColor(context, req['subtotal_score'], req['max_score']).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${req['subtotal_score']} / ${req['max_score']}',
                                          style: TextStyle(
                                            color: _getScoreColor(context, req['subtotal_score'], req['max_score']),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      children: [
                                        if (criteria.isEmpty)
                                          const Text('Không có chi tiết tiêu chí', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11))
                                        else
                                          ...criteria.map((crit) {
                                            final level = crit['level_awarded'] ?? 'fail';
                                            final levelCol = _getLevelColor(context, level);
                                            final statusIcon = level == 'full' ? '✓' : (level == 'partial' ? '~' : '✗');

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration: BoxDecoration(
                                                          color: levelCol.withOpacity(0.12),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          statusIcon,
                                                          style: TextStyle(
                                                            color: levelCol,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          crit['criterion_name'] ?? crit['criterion_id'],
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: levelCol.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '${crit['score_given']} / ${crit['max_score']}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: levelCol,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (crit['feedback'] != null && crit['feedback'].toString().isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '💬 ${crit['feedback']}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

    if (ratio >= 0.8) return const Color(0xFF10B981);
    if (ratio >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getLevelColor(BuildContext context, String? level) {
    switch (level) {
      case 'full':
        return const Color(0xFF10B981);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'fail':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kết quả đã lưu',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Quản lý các file kết quả chấm điểm đã lưu',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _loadResultFiles,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Làm mới'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _resultFiles.isNotEmpty
                        ? () => _showDeleteDialog()
                        : null,
                    icon: const Icon(Icons.delete_sweep, size: 14),
                    label: const Text('Xóa file cũ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                      foregroundColor: const Color(0xFFEF4444),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_resultFiles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open,
                        size: 40,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có file kết quả nào được lưu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.8,
                ),
                itemCount: _resultFiles.length,
                itemBuilder: (context, index) {
                  final file = _resultFiles[index];
                  return _SavedResultGridCard(
                    file: file,
                    onView: () => _viewFileDetails(file.path),
                    onDelete: () => _deleteFile(file.path),
                    formatSize: _formatFileSize,
                  );
                },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

class _SavedResultGridCard extends StatefulWidget {
  final FileSystemEntity file;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final String Function(int) formatSize;

  const _SavedResultGridCard({
    required this.file,
    required this.onView,
    required this.onDelete,
    required this.formatSize,
  });

  @override
  State<_SavedResultGridCard> createState() => _SavedResultGridCardState();
}

class _SavedResultGridCardState extends State<_SavedResultGridCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stat = widget.file.statSync();
    final fileName = widget.file.path.split(Platform.pathSeparator).last;
    final modifiedDate = DateFormat('dd/MM/yyyy HH:mm').format(stat.modified);
    final fileSize = widget.formatSize(stat.size);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark 
              ? (_isHovered ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.4))
              : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? (_isHovered ? const Color(0xFF475569) : const Color(0xFF334155))
                : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.description,
                color: Color(0xFF0EA5E9),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$modifiedDate • $fileSize',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: widget.onView,
                  icon: const Icon(Icons.visibility, size: 16),
                  tooltip: 'Xem chi tiết',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  tooltip: 'Xóa',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
