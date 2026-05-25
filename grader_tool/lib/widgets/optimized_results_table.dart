import 'package:flutter/material.dart';
import 'package:grader_tool/models/grading_result.dart';

/// Optimized results table with lazy loading and pagination, redesigned with premium visual cards
class OptimizedResultsTable extends StatefulWidget {
  final List<GradingResult> results;
  final Function(BuildContext, int) onShowDetails;

  const OptimizedResultsTable({
    super.key,
    required this.results,
    required this.onShowDetails,
  });

  @override
  State<OptimizedResultsTable> createState() => _OptimizedResultsTableState();
}

class _OptimizedResultsTableState extends State<OptimizedResultsTable> {
  static const int _itemsPerPage = 20;
  int _currentPage = 0;

  int get _totalPages => (widget.results.length / _itemsPerPage).ceil();
  
  List<GradingResult> get _currentPageResults {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, widget.results.length);
    return widget.results.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _currentPageResults.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final res = _currentPageResults[index];
              final actualIndex = widget.results.indexOf(res);
              return _OptimizedStudentResultRow(
                result: res,
                onReviewPressed: () => widget.onShowDetails(context, actualIndex),
              );
            },
          ),
        ),
        if (_totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptimizedStudentResultRow extends StatefulWidget {
  final GradingResult result;
  final VoidCallback onReviewPressed;

  const _OptimizedStudentResultRow({
    required this.result,
    required this.onReviewPressed,
  });

  @override
  State<_OptimizedStudentResultRow> createState() => _OptimizedStudentResultRowState();
}

class _OptimizedStudentResultRowState extends State<_OptimizedStudentResultRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = widget.result.score;
    
    late final String gradeLabel;
    late final Color gradeColor;
    if (score >= 80) {
      gradeLabel = 'EXCELLENT';
      gradeColor = const Color(0xFF10B981);
    } else if (score >= 65) {
      gradeLabel = 'GOOD';
      gradeColor = const Color(0xFF0EA5E9);
    } else if (score >= 50) {
      gradeLabel = 'AVERAGE';
      gradeColor = const Color(0xFFF59E0B);
    } else {
      gradeLabel = 'WEAK';
      gradeColor = const Color(0xFFEF4444);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark 
              ? (_isHovered ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.5))
              : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
                ? (_isHovered ? const Color(0xFF475569) : const Color(0xFF334155))
                : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.05 : 0.01),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                color: gradeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.result.studentFile,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student Submission File',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    gradeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: widget.result.score.toStringAsFixed(1),
                          style: TextStyle(color: gradeColor),
                        ),
                        TextSpan(
                          text: ' / 100',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Final Score',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Tooltip(
                  message: widget.result.feedback,
                  child: Text(
                    widget.result.feedback,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: widget.onReviewPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Review'),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
