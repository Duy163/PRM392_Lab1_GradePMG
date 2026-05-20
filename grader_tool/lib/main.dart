import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/ollama_service.dart';

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
  bool _isLoading = false;

  Future<void> _pickFolder() async {
    String? path = await getDirectoryPath();
    if (path != null) {
      setState(() => _solutionsPath = path);
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
      setState(() => _criteriaDocPath = file.path);
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
      setState(() => _excelTemplatePath = file.path);
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

    // Navigate to grading screen
    if (mounted) {
      widget.onNavigateToGrading();
    }
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
            subtitle:
                _solutionsPath ??
                'Select folder containing student .txt files.',
            icon: Icons.folder_zip,
            onTap: _pickFolder,
            isSelected: _solutionsPath != null,
          ),
          const SizedBox(height: 16),
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
  List<TextEditingController> _controllers = [];
  bool _isGrading = false;
  String _progressMessage = '';

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
              FilledButton.tonalIcon(
                onPressed: _results.isNotEmpty ? () {} : null,
                icon: const Icon(Icons.download),
                label: const Text('Export to Excel'),
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
                          DataColumn(label: Text('AI Score')),
                          DataColumn(label: Text('Final Score')),
                          DataColumn(label: Text('AI Feedback')),
                        ],
                        rows: List.generate(_results.length, (index) {
                          return DataRow(
                            cells: [
                              DataCell(Text(_results[index].studentFile)),
                              DataCell(
                                Text(
                                  _results[index].score.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: 80,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 300,
                                  child: Tooltip(
                                    message: _results[index].feedback,
                                    child: Text(
                                      _results[index].feedback,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
              value: 'qwen2.5:7b',
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
                '2. Pull Qwen model: ollama pull qwen2.5:7b\n'
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
