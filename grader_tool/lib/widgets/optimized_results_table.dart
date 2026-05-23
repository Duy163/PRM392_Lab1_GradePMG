import 'package:flutter/material.dart';
import 'package:grader_tool/models/grading_result.dart';

/// Optimized results table with lazy loading and pagination
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
    return Column(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Total Score')),
                  DataColumn(label: Text('Feedback')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _currentPageResults.asMap().entries.map((entry) {
                  final res = entry.value;
                  final actualIndex = widget.results.indexOf(res);
                  return DataRow(
                    cells: [
                      DataCell(Text(res.studentFile)),
                      DataCell(
                        Text(
                          '${res.score.toStringAsFixed(1)} / 100',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Tooltip(
                            message: res.feedback,
                            child: Text(
                              res.feedback,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        FilledButton.tonal(
                          onPressed: () => widget.onShowDetails(context, actualIndex),
                          child: const Text('Review Details'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
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
              ),
              const SizedBox(width: 16),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
