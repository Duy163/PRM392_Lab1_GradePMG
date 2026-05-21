import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/app_state_store.dart';
import 'package:grader_tool/services/ollama_service.dart';
import 'package:grader_tool/services/grading_service.dart';
import 'package:grader_tool/services/grading_store.dart';
import 'package:grader_tool/services/excel_export_service.dart';

void main() {
  runApp(const GraderApp());
}

class GraderApp extends StatelessWidget {
  const GraderApp({super.key});

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
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
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
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('AI Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (int index) {
                setState(() => _selectedIndex = index);
              },
              children: [
                SetupFilesView(
                  onNavigateToGrading: () {
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                const GradingReviewView(),
                const SettingsView(),
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
    const XTypeGroup txtGroup = XTypeGroup(
      label: 'Text',
      extensions: <String>['txt'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[txtGroup],
    );
    if (file != null) {
      final String path = File(file.path).parent.path;
      final int count = _countTxtFiles(path);
      setState(() {
        _solutionsPath = path;
        _folderTxtCount = count;
        AppStateStore.solutionsPath = path;
      });
    }
  }

  Future<void> _pickWordFile() async {
    const XTypeGroup docxTypeGroup = XTypeGroup(
      label: 'Word',
      extensions: <String>['docx'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[docxTypeGroup],
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
    final List<XFile>? files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[txtGroup],
    );
    if (files != null && files.isNotEmpty) {
      setState(() {
        _selectedTxtFiles = files;
        AppStateStore.selectedTxtFiles = files;
        // set solutions path to the folder containing the first selected file
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

    // Test Ollama connection
    setState(() => _isLoading = true);
    final isConnected = await OllamaService.testConnection();
    setState(() => _isLoading = false);

    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Cannot connect to Ollama. Make sure it\'s running on localhost:11434',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Start grading (use selected files if provided)
    setState(() => _isLoading = true);
    List<GradingResult> results = await GradingService.gradeAllStudents(
      criteriaDocPath: _criteriaDocPath!,
      solutionsFolderPath: _solutionsPath,
      selectedFilePaths: _selectedTxtFiles?.map((f) => f.path).toList(),
      onProgress: (msg) {
        // Optionally show progress in SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(milliseconds: 800),
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

    // Publish results and navigate to review page
    GradingStore.mergeResults(results);
    if (mounted) widget.onNavigateToGrading();
  }

  @override
  Widget build(BuildContext context) {
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
          _buildFileSelectCard(
            title: 'Student Solutions Folder',
            subtitle: _solutionsPath != null
                ? '$_solutionsPath\n(Found ${_folderTxtCount ?? 0} .txt files)'
                : 'Select any student .txt file to choose its folder',
            icon: Icons.folder_zip,
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
          _buildFileSelectCard(
            title: 'Grading Criteria Document',
            subtitle: _criteriaDocPath ?? 'Select the .docx rubric file.',
            icon: Icons.description,
            onTap: _pickWordFile,
            isSelected: _criteriaDocPath != null,
          ),
          const SizedBox(height: 16),
          _buildFileSelectCard(
            title: 'Scores Excel Template',
            subtitle: _excelTemplatePath ?? 'Select the .xlsx output file.',
            icon: Icons.table_chart,
            onTap: _pickExcelFile,
            isSelected: _excelTemplatePath != null,
          ),
          const SizedBox(height: 48),
          Align(
            alignment: Alignment.centerRight,
            child: _isLoading
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(),
                  )
                : FilledButton.icon(
                    onPressed:
                        (_solutionsPath != null &&
                            _criteriaDocPath != null &&
                            _excelTemplatePath != null)
                        ? _startGrading
                        : null,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Start AI Grading'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
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
    final List<XFile>? files = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[txtGroup],
    );
    if (files != null && files.isNotEmpty) {
      await _gradeMoreFiles(files.map((f) => f.path).toList());
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
    List<GradingResult> results = await GradingService.gradeAllStudents(
      criteriaDocPath: AppStateStore.criteriaDocPath!,
      selectedFilePaths: filePaths,
      onProgress: (msg) {
        if (mounted) {
          setState(() => _progressMessage = msg);
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
    setState(() => _isGrading = false);

    GradingStore.mergeResults(results);
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

                            if (markerName == null || markerName.isEmpty)
                              return;

                            final path = await ExcelExportService.exportToExcel(
                              _results,
                              markerName,
                            );
                            if (!mounted) return;
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
          const SizedBox(height: 24),
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
                          DataColumn(label: Text('AI Feedback')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: List.generate(_results.length, (index) {
                          final res = _results[index];
                          return DataRow(
                            cells: [
                              DataCell(Text(res.studentFile)),
                              DataCell(
                                Text(
                                  res.score.toStringAsFixed(1),
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
                                      _showDetailsDialog(context, index),
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

  void _showDetailsDialog(BuildContext context, int index) {
    final res = _results[index];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                            'AI Grading Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: res.questions.isEmpty
                                ? const Center(
                                    child: Text('No detailed questions found.'),
                                  )
                                : ListView.builder(
                                    itemCount: res.questions.length,
                                    itemBuilder: (context, qIndex) {
                                      final q = res.questions[qIndex];
                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Question ${q.questionNumber}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  SizedBox(
                                                    width: 100,
                                                    child: TextFormField(
                                                      initialValue: q.score
                                                          .toStringAsFixed(1),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Score',
                                                            isDense: true,
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                      onChanged: (val) {
                                                        final newScore =
                                                            double.tryParse(
                                                              val,
                                                            );
                                                        if (newScore != null) {
                                                          q.score = newScore;
                                                          setState(() {});
                                                          setDialogState(() {});
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Mistake: ${q.mistake}',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text('Feedback: ${q.feedback}'),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
            _buildSettingsCard(
              title: 'API Endpoint',
              value: 'http://localhost:11434',
              icon: Icons.api,
              context: context,
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Model',
              value: 'qwen2.5:1.5b',
              icon: Icons.model_training,
              context: context,
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Status',
              value: 'Ready to connect',
              icon: Icons.cloud_done,
              context: context,
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
                '1. Make sure Ollama is running: ollama serve\n'
                '2. Pull Qwen model: ollama pull qwen2.5:1.5b\n'
                '3. Verify at: http://localhost:11434/api/tags\n'
                '4. Return to Setup and start grading!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String value,
    required IconData icon,
    required BuildContext context,
  }) {
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
