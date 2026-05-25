import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/app_state_store.dart';
import 'package:grader_tool/services/grading_service.dart';
import 'package:grader_tool/services/grading_store.dart';
import 'package:grader_tool/services/excel_export_service.dart';
import 'package:grader_tool/views/saved_results_view.dart';

void main() {
  runApp(const GraderApp());
}

class GraderApp extends StatelessWidget {
  const GraderApp({super.key});

  // ignore: member-ordering
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Desktop Grader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Qwen AI Auto Grader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_open_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Setup Files'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Review & Export'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Saved Results'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                SetupFilesView(
                  onNavigateToGrading: () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
                const GradingReviewView(),
                const SavedResultsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SetupFilesView extends StatefulWidget {
  final VoidCallback onNavigateToGrading;

  const SetupFilesView({super.key, required this.onNavigateToGrading});

  @override
  State<SetupFilesView> createState() => _SetupFilesViewState();
}

class _SetupFilesViewState extends State<SetupFilesView> {
  String? _solutionsPath;
  String? _criteriaDocPath;
  String? _excelTemplatePath;
  List<XFile>? _selectedTxtFiles;
  bool _isLoading = false;
  int? _folderTxtCount;

  bool get _canStartGrading {
    return _solutionsPath != null &&
        _criteriaDocPath != null &&
        _excelTemplatePath != null;
  }

  @override
  void initState() {
    super.initState();
    _solutionsPath = AppStateStore.solutionsPath;
    _criteriaDocPath = AppStateStore.criteriaDocPath;
    _excelTemplatePath = AppStateStore.excelTemplatePath;
    _selectedTxtFiles = AppStateStore.selectedTxtFiles;
    if (_solutionsPath != null) {
      _folderTxtCount = _countTxtFiles(_solutionsPath!);
    }
  }

  int _countTxtFiles(String path) {
    try {
      final dir = Directory(path);
      return dir
          .listSync()
          .where((e) => e.path.toLowerCase().endsWith('.txt'))
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _pickFolder() async {
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: 'Select Folder',
    );
    if (directoryPath != null) {
      final int count = _countTxtFiles(directoryPath);
      setState(() {
        _solutionsPath = directoryPath;
        _folderTxtCount = count;
        AppStateStore.solutionsPath = directoryPath;
      });
    }
  }

  Future<void> _pickRubricFile() async {
    const rubricTypeGroup = XTypeGroup(
      label: 'Rubric',
      extensions: <String>['docx', 'json'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[rubricTypeGroup],
    );
    if (file != null) {
      setState(() {
        _criteriaDocPath = file.path;
        AppStateStore.criteriaDocPath = file.path;
      });
    }
  }

  Future<void> _pickExcelFile() async {
    const XTypeGroup excelTypeGroup = XTypeGroup(
      label: 'Excel',
      extensions: <String>['xlsx'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[excelTypeGroup],
    );
    if (file != null) {
      setState(() {
        _excelTemplatePath = file.path;
        AppStateStore.excelTemplatePath = file.path;
      });
    }
  }

  Future<void> _pickTxtFiles() async {
    const XTypeGroup txtGroup = XTypeGroup(
      label: 'Text',
      extensions: <String>['txt'],
    );
    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[txtGroup]);
    if (files.isNotEmpty) {
      setState(() {
        _selectedTxtFiles = files;
        AppStateStore.selectedTxtFiles = files;
        _solutionsPath = File(files.first.path).parent.path;
        AppStateStore.solutionsPath = _solutionsPath;
        _folderTxtCount = _countTxtFiles(_solutionsPath!);
      });
    }
  }

  Future<void> _startGrading() async {
    if (_solutionsPath == null ||
        _criteriaDocPath == null ||
        _excelTemplatePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please select all required files')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final results = await GradingService.gradeAllStudents(
      criteriaDocPath: _criteriaDocPath!,
      solutionsFolderPath: _solutionsPath,
      selectedFilePaths: _selectedTxtFiles?.map((f) => f.path).toList(),
      onProgress: (msg) {
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          // Dismiss the current SnackBar immediately to avoid queuing them up!
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), duration: const Duration(seconds: 2)),
          );
        }
      },
    );
    setState(() => _isLoading = false);

    // Clear all snackbars instantly when grading finishes!
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    GradingStore.mergeResults(results);
    if (mounted) widget.onNavigateToGrading();
  }

  @override
  Widget build(BuildContext context) {
    final Widget startAction;
    if (_isLoading) {
      startAction = const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(),
      );
    } else {
      startAction = FilledButton.icon(
        onPressed: _canStartGrading ? _startGrading : null,
        icon: const Icon(Icons.rocket_launch),
        label: const Text('Start Grading'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workspace Setup',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Select the necessary files to start the grading process.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FileSelectCard(
            title: 'Student Solutions Folder',
            subtitle: _solutionsPath != null
                ? '$_solutionsPath\n(Found ${_folderTxtCount ?? 0} .txt files)'
                : 'Click to select folder containing student .txt files',
            icon: Icons.folder_open,
            onTap: _pickFolder,
            isSelected: _solutionsPath != null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickTxtFiles,
                icon: const Icon(Icons.file_open),
                label: Text(
                  _selectedTxtFiles == null
                      ? 'Or pick specific .txt files'
                      : 'Selected ${_selectedTxtFiles!.length} .txt files',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FileSelectCard(
            title: 'Grading Criteria Document / JSON Rubric',
            subtitle:
                _criteriaDocPath ?? 'Select the .docx or .json rubric file.',
            icon: Icons.description,
            onTap: _pickRubricFile,
            isSelected: _criteriaDocPath != null,
          ),
          const SizedBox(height: 16),
          FileSelectCard(
            title: 'Scores Excel Template',
            subtitle: _excelTemplatePath ?? 'Select the .xlsx output file.',
            icon: Icons.table_chart,
            onTap: _pickExcelFile,
            isSelected: _excelTemplatePath != null,
          ),
          const SizedBox(height: 24),
          GradingModeCard(
            useFastGrader: AppStateStore.useFastGrader,
            onSelectAdvanced: () {
              setState(() {
                AppStateStore.useFastGrader = false;
              });
            },
            onSelectFast: () {
              setState(() {
                AppStateStore.useFastGrader = true;
              });
            },
          ),
          const SizedBox(height: 32),
          Align(alignment: Alignment.centerRight, child: startAction),
        ],
      ),
    );
  }
}

class GradingModeCard extends StatelessWidget {
  final bool useFastGrader;
  final VoidCallback onSelectAdvanced;
  final VoidCallback onSelectFast;

  const GradingModeCard({
    super.key,
    required this.useFastGrader,
    required this.onSelectAdvanced,
    required this.onSelectFast,
  });

  // ignore: member-ordering
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grading Mode (Chế độ chấm điểm)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSelectAdvanced,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !useFastGrader
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !useFastGrader
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                color: !useFastGrader
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Advanced AI (Ollama)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'High precision grading using your local Ollama LLM. Best for small batches.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSelectFast,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: useFastGrader
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: useFastGrader
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bolt,
                                color: useFastGrader
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '⚡ Fast Local Grader',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Instant grading based on keywords & density. Grades 1000+ files in seconds.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
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

class FileSelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const FileSelectCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                ElevatedButton(onPressed: onTap, child: const Text('Browse')),
            ],
          ),
        ),
      ),
    );
  }
}

class GradingReviewView extends StatefulWidget {
  const GradingReviewView({super.key});

  @override
  State<GradingReviewView> createState() => _GradingReviewViewState();
}

class _GradingReviewViewState extends State<GradingReviewView> {
  List<GradingResult> _results = [];
  bool _isGrading = false;
  String _progressMessage = '';
  String _scoreFilter = 'All';

  List<GradingResult> get _filteredResults {
    if (_scoreFilter == 'All') return _results;
    return _results.where((res) {
      final score = res.score;
      if (_scoreFilter == 'Excellent') return score >= 80;
      if (_scoreFilter == 'Good') return score >= 65 && score < 80;
      if (_scoreFilter == 'Average') return score >= 50 && score < 65;
      if (_scoreFilter == 'Weak') return score < 50;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _results = GradingStore.latestResults;
    if (_results.isNotEmpty) {
      _progressMessage = 'Received ${_results.length} graded submissions';
    }

    GradingStore.stream.listen((results) {
      setState(() {
        _results = results;
        _progressMessage = 'Received ${results.length} graded submissions';
      });
    });
  }

  Future<void> _pickMoreTxtFiles() async {
    const XTypeGroup txtGroup = XTypeGroup(
      label: 'Text',
      extensions: <String>['txt'],
    );
    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[txtGroup]);
    if (files.isNotEmpty) {
      await _gradeMoreFiles(files.map((f) => f.path).toList());
    }
  }

  Future<void> _pickMoreFolder() async {
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: 'Select Folder',
    );
    if (directoryPath != null) {
      if (AppStateStore.criteriaDocPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Grading criteria path not found')),
          );
        }
        return;
      }

      setState(() => _isGrading = true);
      final results = await GradingService.gradeAllStudents(
        criteriaDocPath: AppStateStore.criteriaDocPath!,
        solutionsFolderPath: directoryPath,
        onProgress: (msg) {
          if (mounted) setState(() => _progressMessage = msg);
        },
        onError: (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );
      setState(() => _isGrading = false);

      GradingStore.mergeResults(results);
    }
  }

  Future<void> _gradeMoreFiles(List<String> filePaths) async {
    if (AppStateStore.criteriaDocPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Grading criteria path not found')),
        );
      }
      return;
    }

    setState(() => _isGrading = true);
    final results = await GradingService.gradeAllStudents(
      criteriaDocPath: AppStateStore.criteriaDocPath!,
      selectedFilePaths: filePaths,
      onProgress: (msg) {
        if (mounted) setState(() => _progressMessage = msg);
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), duration: const Duration(seconds: 2)),
          );
        }
      },
    );
    setState(() => _isGrading = false);

    GradingStore.mergeResults(results);
  }

  // ignore: member-ordering
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
              Text(
                'Review & Adjust Scores',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _isGrading ? null : _pickMoreTxtFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add More Submissions'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isGrading ? null : _pickMoreFolder,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Add Folder'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.tonalIcon(
                    onPressed: _results.isNotEmpty && !_isGrading
                        ? () async {
                            final markerNameController =
                                TextEditingController();
                            final String? markerName = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Enter Marker Name'),
                                  content: TextField(
                                    controller: markerNameController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g., HungLD5',
                                    ),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop(markerNameController.text.trim()),
                                      child: const Text('Export'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (markerName == null || markerName.isEmpty) {
                              return;
                            }

                            final path = await ExcelExportService.exportToExcel(
                              _results,
                              markerName,
                            );
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            if (path != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Exported to: $path')),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to export to Excel.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Export to Excel'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_progressMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_progressMessage),
            ),
          if (_isGrading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 16),
          GradingDashboard(results: _results),
          ScoreFilterChips(
            results: _results,
            selectedFilter: _scoreFilter,
            onSelected: (filter) {
              setState(() {
                _scoreFilter = filter;
              });
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No grades yet. Select files and start grading.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                : Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.resolveWith(
                          (states) => Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        columns: const [
                          DataColumn(label: Text('Student')),
                          DataColumn(label: Text('Total Score')),
                          DataColumn(label: Text('Feedback')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: List.generate(_filteredResults.length, (index) {
                          final res = _filteredResults[index];
                          final actualIndex = _results.indexOf(res);
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
                                  onPressed: () =>
                                      _showDetailsDialog(context, actualIndex),
                                  child: const Text('Review Details'),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _editCriterionScore(
    BuildContext context,
    int resultIndex,
    int requirementIndex,
    int criterionIndex,
    CriterionScore criterion,
    VoidCallback onSaved,
  ) {
    final controller = TextEditingController(
      text: criterion.scoreGiven.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chỉnh sửa điểm: ${criterion.criterionId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                criterion.criterionName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Điểm số',
                  hintText: 'Nhập điểm (0 - ${criterion.maxScore})',
                  border: const OutlineInputBorder(),
                  suffixText: '/ ${criterion.maxScore}',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level hiện tại: ${criterion.levelAwarded}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                final newScore = double.tryParse(controller.text);
                if (newScore != null &&
                    newScore >= 0 &&
                    newScore <= criterion.maxScore) {
                  String levelAwarded;
                  if (newScore == criterion.maxScore) {
                    levelAwarded = 'full';
                  } else if (newScore > 0) {
                    levelAwarded = 'partial';
                  } else {
                    levelAwarded = 'fail';
                  }

                  // Create new criterion with updated score
                  final updatedCriterion = CriterionScore(
                    criterionId: criterion.criterionId,
                    criterionName: criterion.criterionName,
                    scoreGiven: newScore,
                    maxScore: criterion.maxScore,
                    levelAwarded: levelAwarded,
                    feedback: criterion.feedback,
                  );

                  // Create new criteria list with updated criterion
                  final updatedCriteria = List<CriterionScore>.from(
                    _results[resultIndex]
                        .requirements[requirementIndex]
                        .criteria,
                  );
                  updatedCriteria[criterionIndex] = updatedCriterion;

                  // Calculate new subtotal
                  final newSubtotal = updatedCriteria.fold<double>(
                    0.0,
                    (sum, c) => sum + c.scoreGiven,
                  );

                  // Create new requirement with updated data
                  final req =
                      _results[resultIndex].requirements[requirementIndex];
                  final updatedRequirement = RequirementScore(
                    requirementId: req.requirementId,
                    requirementName: req.requirementName,
                    subtotalScore: newSubtotal,
                    maxScore: req.maxScore,
                    commonMistakesDetected: req.commonMistakesDetected,
                    matchedCriteria: req.matchedCriteria,
                    missingCriteria: req.missingCriteria,
                    criteria: updatedCriteria,
                  );

                  // Create new requirements list
                  final updatedRequirements = List<RequirementScore>.from(
                    _results[resultIndex].requirements,
                  );
                  updatedRequirements[requirementIndex] = updatedRequirement;

                  // Calculate new total
                  final newTotal = updatedRequirements.fold<double>(
                    0.0,
                    (sum, r) => sum + r.subtotalScore,
                  );

                  // Create new result
                  final result = _results[resultIndex];
                  final updatedResult = GradingResult(
                    studentFile: result.studentFile,
                    submissionContent: result.submissionContent,
                    requirements: updatedRequirements,
                    totalScore: newTotal,
                    feedback: result.feedback,
                    fullResponse: result.fullResponse,
                  );

                  // Update parent view state and store
                  setState(() {
                    _results[resultIndex] = updatedResult;
                  });

                  // Update GradingStore to persist changes
                  GradingStore.mergeResults([updatedResult]);

                  // Update global store immediately
                  GradingStore.mergeResults([updatedResult]);

                  // Trigger dialog rebuild
                  onSaved();

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật điểm')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Điểm không hợp lệ (0-${criterion.maxScore})',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final res = _results[index];
            return AlertDialog(
              title: Text('Grading Details: ${res.studentFile}'),
              content: SizedBox(
                width: 1200,
                height: 700,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Submission',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  res.submissionContent,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rubric Scoring Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: res.requirements.isEmpty
                                ? const Center(
                                    child: Text('No detailed questions found.'),
                                  )
                                : ListView.builder(
                                    itemCount: res.requirements.length,
                                    itemBuilder: (context, qIndex) {
                                      final q = res.requirements[qIndex];

                                      // DEBUG: Print requirement info
                                      debugPrint(
                                        '=== UI DEBUG: Requirement $qIndex ===',
                                      );
                                      debugPrint('ID: ${q.requirementId}');
                                      debugPrint('Name: ${q.requirementName}');
                                      debugPrint(
                                        'Criteria count: ${q.criteria.length}',
                                      );
                                      if (q.criteria.isNotEmpty) {
                                        for (var c in q.criteria) {
                                          debugPrint(
                                            '  - ${c.criterionId}: ${c.criterionName} (${c.scoreGiven}/${c.maxScore})',
                                          );
                                        }
                                      }

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                16,
                                                0,
                                                16,
                                                16,
                                              ),
                                          title: Text(
                                            '${q.requirementId} - ${q.requirementName}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${q.subtotalScore.toStringAsFixed(1)} / ${q.maxScore.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          children: [
                                            // Danh sách criteria chi tiết
                                            if (q.criteria.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              ...q.criteria.map((item) {
                                                final isPass =
                                                    item.scoreGiven > 0;
                                                late final Color statusColor;
                                                late final String statusIcon;
                                                if (isPass) {
                                                  statusColor = Theme.of(
                                                    context,
                                                  ).colorScheme.primary;
                                                  statusIcon = '✓';
                                                } else {
                                                  statusColor = Theme.of(
                                                    context,
                                                  ).colorScheme.error;
                                                  statusIcon = '✗';
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                        left: 8,
                                                        right: 8,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        statusIcon,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: RichText(
                                                          text: TextSpan(
                                                            style:
                                                                DefaultTextStyle.of(
                                                                  context,
                                                                ).style,
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    '${item.criterionId}: ',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text: item
                                                                    .criterionName,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        '${item.scoreGiven.toStringAsFixed(1)}/${item.maxScore.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () =>
                                                            _editCriterionScore(
                                                              context,
                                                              index,
                                                              qIndex,
                                                              q.criteria
                                                                  .indexOf(
                                                                    item,
                                                                  ),
                                                              item,
                                                              () {
                                                                setStateDialog(
                                                                  () {},
                                                                );
                                                              },
                                                            ),
                                                        tooltip:
                                                            'Chỉnh sửa điểm',
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ] else ...[
                                              const Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: Text(
                                                  'No criteria details available',
                                                  style: TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            // Common mistakes nếu có
                                            if (q
                                                .commonMistakesDetected
                                                .isNotEmpty) ...[
                                              const Divider(),
                                              const SizedBox(height: 8),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8.0,
                                                    ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 18,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Common mistakes: ${q.commonMistakesDetected.join(', ')}',
                                                        style: TextStyle(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ],
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
              actions: [
                TextButton(
                  onPressed: () {
                    GradingStore.mergeResults(_results);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class GradingDashboard extends StatelessWidget {
  final List<GradingResult> results;

  const GradingDashboard({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final total = results.length;
    final avg = total == 0
        ? 0.0
        : results.fold<double>(0.0, (sum, r) => sum + r.score) / total;
    final passCount = results.where((r) => r.score >= 50).length;
    final passRate = total == 0 ? 0.0 : (passCount / total) * 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              title: 'Total Graded (Đã chấm)',
              value: '$total học sinh',
              subtitle: 'Student submissions processed',
              icon: Icons.people,
              color: Theme.of(context).colorScheme.primaryContainer,
              onColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MetricCard(
              title: 'Class Average (ĐTB Lớp)',
              value: '${avg.toStringAsFixed(1)} / 100',
              subtitle: 'Average points scored',
              icon: Icons.analytics,
              color: Theme.of(context).colorScheme.secondaryContainer,
              onColor: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MetricCard(
              title: 'Pass Rate (Tỷ lệ đạt)',
              value: '${passRate.toStringAsFixed(1)}%',
              subtitle: '$passCount / $total scored >= 50',
              icon: Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              onColor: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color onColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: onColor.withAlpha((0.1 * 255).round()),
              radius: 24,
              child: Icon(icon, color: onColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: onColor.withAlpha((0.8 * 255).round()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: onColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: onColor.withAlpha((0.6 * 255).round()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreFilterChips extends StatelessWidget {
  final List<GradingResult> results;
  final String selectedFilter;
  final ValueChanged<String> onSelected;

  const ScoreFilterChips({
    super.key,
    required this.results,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final counts = {
      'All': results.length,
      'Excellent': results.where((r) => r.score >= 80).length,
      'Good': results.where((r) => r.score >= 65 && r.score < 80).length,
      'Average': results.where((r) => r.score >= 50 && r.score < 65).length,
      'Weak': results.where((r) => r.score < 50).length,
    };

    final labels = {
      'All': 'Tất cả',
      'Excellent': 'Xuất sắc (>= 80)',
      'Good': 'Khá (65-79)',
      'Average': 'Trung bình (50-64)',
      'Weak': 'Yếu (< 50)',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: labels.keys.map((filter) {
          final isCurrent = selectedFilter == filter;
          final count = counts[filter] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text('${labels[filter]} ($count)'),
              selected: isCurrent,
              onSelected: (selected) {
                if (selected) {
                  onSelected(filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Configuration',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            const SettingsCard(
              title: 'API Endpoint',
              value: 'http://localhost:11434',
              icon: Icons.api,
            ),
            const SizedBox(height: 16),
            const SettingsCard(
              title: 'Model',
              value: 'Rubric JSON Parser',
              icon: Icons.model_training,
            ),
            const SizedBox(height: 16),
            const SettingsCard(
              title: 'Status',
              value: 'Ready to grade',
              icon: Icons.cloud_done,
            ),
            const SizedBox(height: 32),
            Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1. Rubric can be .json or .docx\n'
                '2. Student submissions must be .txt\n'
                '3. Exported Excel includes both /100 and /10 scores\n'
                '4. Return to Setup and start grading!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const SettingsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
