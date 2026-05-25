import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/app_state_store.dart';
import 'package:grader_tool/services/grading_service.dart';
import 'package:grader_tool/services/grading_store.dart';
import 'package:grader_tool/services/excel_export_service.dart';
import 'package:grader_tool/views/saved_results_view.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const GraderApp());
}

class GraderApp extends StatelessWidget {
  const GraderApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFF6366F1),
      fontFamily: 'DM Sans',
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFFAFAFE),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF0F172A),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2.0),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      dividerTheme: DividerThemeData(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Desktop Grader',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          CustomSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
          ),
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFFAFAFE),
              child: Stack(
                children: [
                  // Beautiful radial glows for dynamic high-end feel
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -50,
                    child: Container(
                      width: 450,
                      height: 450,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0EA5E9).withOpacity(isDark ? 0.06 : 0.04),
                      ),
                    ),
                  ),
                  // Background grid tint
                  Positioned.fill(
                    child: Opacity(
                      opacity: isDark ? 0.015 : 0.03,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=40&q=10'),
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The viewport content
                  SafeArea(
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
                        const SettingsView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header Profile Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                // Avatar with online status
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withOpacity(0.12),
                      child: Text(
                        'QA',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF111827) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Courtney Henry',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),
          // Sidebar menu items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.folder_open_outlined,
                    selectedIcon: Icons.folder,
                    label: 'Setup Files',
                    isSelected: selectedIndex == 0,
                    onTap: () => onDestinationSelected(0),
                  ),
                  const SizedBox(height: 6),
                  _SidebarItem(
                    icon: Icons.analytics_outlined,
                    selectedIcon: Icons.analytics,
                    label: 'Review & Export',
                    isSelected: selectedIndex == 1,
                    onTap: () => onDestinationSelected(1),
                  ),
                  const SizedBox(height: 6),
                  _SidebarItem(
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history,
                    label: 'Saved Results',
                    isSelected: selectedIndex == 2,
                    onTap: () => onDestinationSelected(2),
                  ),
                  const SizedBox(height: 6),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    isSelected: selectedIndex == 3,
                    onTap: () => onDestinationSelected(3),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Banner Card (Prodify AI Style)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF818CF8),
                    Color(0xFF4F46E5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Qwen AI Engine',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ensure Ollama runs locally on port 11434 to utilize Advanced AI.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      onDestinationSelected(3);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Configure'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    
    Color getBgColor() {
      if (widget.isSelected) {
        return isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
      }
      if (_isHovered) {
        return isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
      }
      return Colors.transparent;
    }

    Color getTextColor() {
      if (widget.isSelected) {
        return primaryColor;
      }
      return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: getBgColor(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                color: getTextColor(),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: getTextColor(),
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ViewHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const ViewHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
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
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
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
        icon: const Icon(Icons.rocket_launch, size: 16),
        label: const Text('Start Grading'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: _canStartGrading ? 4 : 0,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ViewHeader(
            title: 'Hello, Courtney',
            subtitle: 'How can I help you grade today?',
          ),
          const SizedBox(height: 16),
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
                icon: const Icon(Icons.file_open, size: 14),
                label: Text(
                  _selectedTxtFiles == null
                      ? 'Or pick specific .txt files'
                      : 'Selected ${_selectedTxtFiles!.length} .txt files',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune,
                  color: primaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Grading Mode (Chế độ chấm điểm)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GradingModeOptionTile(
                  title: 'Advanced AI (Ollama)',
                  subtitle: 'High precision grading using your local Ollama LLM. Best for small batches.',
                  icon: Icons.psychology,
                  isSelected: !useFastGrader,
                  onTap: onSelectAdvanced,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GradingModeOptionTile(
                  title: '⚡ Fast Local Grader',
                  subtitle: 'Instant grading based on keywords & density. Grades 1000+ files in seconds.',
                  icon: Icons.bolt,
                  isSelected: useFastGrader,
                  onTap: onSelectFast,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradingModeOptionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GradingModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GradingModeOptionTile> createState() => _GradingModeOptionTileState();
}

class _GradingModeOptionTileState extends State<_GradingModeOptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    
    Color tileBg;
    Color borderCol;
    if (widget.isSelected) {
      tileBg = isDark ? const Color(0xFF1E1F35) : const Color(0xFFEEF2FF);
      borderCol = primaryColor;
    } else {
      tileBg = isDark 
          ? (_isHovered ? const Color(0xFF1E293B) : Colors.transparent)
          : (_isHovered ? const Color(0xFFF8FAFC) : Colors.transparent);
      borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderCol,
            width: widget.isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: widget.isSelected 
                              ? primaryColor 
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FileSelectCard extends StatefulWidget {
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
  State<FileSelectCard> createState() => _FileSelectCardState();
}

class _FileSelectCardState extends State<FileSelectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1);
    
    Color cardBg;
    Color borderColor;
    if (widget.isSelected) {
      cardBg = isDark ? const Color(0xFF1E1F35) : const Color(0xFFEEF2FF);
      borderColor = primaryColor;
    } else {
      cardBg = isDark 
          ? (_isHovered ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.6))
          : (_isHovered ? const Color(0xFFF1F5F9) : Colors.white);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.15) : const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: _isHovered ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.isSelected 
                          ? primaryColor.withOpacity(0.15) 
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: widget.isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (widget.isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Browse'),
                    ),
                ],
              ),
            ),
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
      if (mounted) {
        setState(() {
          _results = results;
          _progressMessage = 'Received ${results.length} graded submissions';
        });
      }
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
      if (mounted) setState(() => _isGrading = false);

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
    if (mounted) setState(() => _isGrading = false);

    GradingStore.mergeResults(results);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ViewHeader(
            title: 'Review & Adjust Scores',
            subtitle: 'Inspect results, adjust detailed points, and export to Excel.',
            trailing: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isGrading ? null : _pickMoreTxtFiles,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Files'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _isGrading ? null : _pickMoreFolder,
                  icon: const Icon(Icons.create_new_folder, size: 14),
                  label: const Text('Add Folder'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
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
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Export to Excel'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          if (_progressMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _progressMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isGrading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                minHeight: 6,
                backgroundColor: Colors.transparent,
                color: Color(0xFF6366F1),
              ),
            ),
          const SizedBox(height: 8),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64.0),
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
                              Icons.assignment_outlined,
                              size: 40,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No grades yet. Select files and start grading.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Go to "Setup Files" to configure paths and launch the auto-grader.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final res = _filteredResults[index];
                      final actualIndex = _results.indexOf(res);
                      return _StudentResultRow(
                        result: res,
                        onReviewPressed: () => _showDetailsDialog(context, actualIndex),
                      );
                    },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Score: ${criterion.criterionId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                criterion.criterionName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Points Awarded',
                  hintText: 'Enter score (0 - ${criterion.maxScore})',
                  suffixText: '/ ${criterion.maxScore}',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Current Status: ${criterion.levelAwarded.toUpperCase()}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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

                  final updatedCriterion = CriterionScore(
                    criterionId: criterion.criterionId,
                    criterionName: criterion.criterionName,
                    scoreGiven: newScore,
                    maxScore: criterion.maxScore,
                    levelAwarded: levelAwarded,
                    feedback: criterion.feedback,
                  );

                  final updatedCriteria = List<CriterionScore>.from(
                    _results[resultIndex]
                        .requirements[requirementIndex]
                        .criteria,
                  );
                  updatedCriteria[criterionIndex] = updatedCriterion;

                  final newSubtotal = updatedCriteria.fold<double>(
                    0.0,
                    (sum, c) => sum + c.scoreGiven,
                  );

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

                  final updatedRequirements = List<RequirementScore>.from(
                    _results[resultIndex].requirements,
                  );
                  updatedRequirements[requirementIndex] = updatedRequirement;

                  final newTotal = updatedRequirements.fold<double>(
                    0.0,
                    (sum, r) => sum + r.subtotalScore,
                  );

                  final result = _results[resultIndex];
                  final updatedResult = GradingResult(
                    studentFile: result.studentFile,
                    submissionContent: result.submissionContent,
                    requirements: updatedRequirements,
                    totalScore: newTotal,
                    feedback: result.feedback,
                    fullResponse: result.fullResponse,
                  );

                  setState(() {
                    _results[resultIndex] = updatedResult;
                  });

                  GradingStore.mergeResults([updatedResult]);
                  onSaved();

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Points updated successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invalid score (must be between 0 and ${criterion.maxScore})',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 24,
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                width: 1100,
                height: 750,
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
                                color: const Color(0xFF6366F1).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.assignment_ind, color: Color(0xFF6366F1), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grading Review Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  res.studentFile,
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
                                      text: res.score.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    const TextSpan(text: ' / 100'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                GradingStore.mergeResults(_results);
                                Navigator.of(context).pop();
                              },
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
                          // Left side: Student Submission view
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Student Submission Code/Text',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        res.submissionContent,
                                        style: TextStyle(
                                          fontFamily: 'Consolas',
                                          fontSize: 12,
                                          height: 1.5,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right side: Rubric Scoring details
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rubric Scoring Details',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: res.requirements.isEmpty
                                      ? const Center(
                                          child: Text('No detailed requirements found.'),
                                        )
                                      : ListView.builder(
                                          itemCount: res.requirements.length,
                                          itemBuilder: (context, qIndex) {
                                            final q = res.requirements[qIndex];

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
                                                data: Theme.of(context).copyWith(
                                                  dividerColor: Colors.transparent,
                                                ),
                                                child: ExpansionTile(
                                                  initiallyExpanded: true,
                                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                  title: Text(
                                                    '${q.requirementId} - ${q.requirementName}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  trailing: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      '${q.subtotalScore.toStringAsFixed(1)} / ${q.maxScore.toStringAsFixed(1)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                        color: Color(0xFF6366F1),
                                                      ),
                                                    ),
                                                  ),
                                                  children: [
                                                    if (q.criteria.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      ...q.criteria.map((item) {
                                                        final isPass = item.scoreGiven > 0;
                                                        final statusColor = isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                                                        final statusIcon = isPass ? '✓' : '✗';

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
                                                          child: Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Container(
                                                                margin: const EdgeInsets.only(top: 2),
                                                                width: 18,
                                                                height: 18,
                                                                decoration: BoxDecoration(
                                                                  color: statusColor.withOpacity(0.12),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                alignment: Alignment.center,
                                                                child: Text(
                                                                  statusIcon,
                                                                  style: TextStyle(
                                                                    color: statusColor,
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 11,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    RichText(
                                                                      text: TextSpan(
                                                                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
                                                                        children: [
                                                                          TextSpan(
                                                                            text: '${item.criterionId}: ',
                                                                            style: TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                            ),
                                                                          ),
                                                                          TextSpan(
                                                                            text: item.criterionName,
                                                                            style: TextStyle(
                                                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    if (item.feedback.isNotEmpty) ...[
                                                                      const SizedBox(height: 6),
                                                                      Text(
                                                                        '💬 ${item.feedback}',
                                                                        style: TextStyle(
                                                                          fontSize: 11,
                                                                          fontStyle: FontStyle.italic,
                                                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    '${item.scoreGiven.toStringAsFixed(1)}/${item.maxScore.toStringAsFixed(1)}',
                                                                    style: TextStyle(
                                                                      color: statusColor,
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  IconButton(
                                                                    icon: const Icon(Icons.edit, size: 13),
                                                                    padding: EdgeInsets.zero,
                                                                    constraints: const BoxConstraints(),
                                                                    onPressed: () => _editCriterionScore(
                                                                      context,
                                                                      index,
                                                                      qIndex,
                                                                      q.criteria.indexOf(item),
                                                                      item,
                                                                      () {
                                                                        setStateDialog(() {});
                                                                      },
                                                                    ),
                                                                    tooltip: 'Edit Score',
                                                                    style: IconButton.styleFrom(
                                                                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                    ] else ...[
                                                      const Padding(
                                                        padding: EdgeInsets.all(12.0),
                                                        child: Text(
                                                          'No criteria details available',
                                                          style: TextStyle(
                                                            fontStyle: FontStyle.italic,
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    if (q.commonMistakesDetected.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Container(
                                                        padding: const EdgeInsets.all(10),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEF4444).withOpacity(0.06),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                                                            const SizedBox(width: 6),
                                                            Expanded(
                                                              child: Text(
                                                                'Mistakes: ${q.commonMistakesDetected.join(', ')}',
                                                                style: const TextStyle(
                                                                  color: Color(0xFFEF4444),
                                                                  fontStyle: FontStyle.italic,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
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
            );
          },
        );
      },
    );
  }
}

class _StudentResultRow extends StatefulWidget {
  final GradingResult result;
  final VoidCallback onReviewPressed;

  const _StudentResultRow({
    required this.result,
    required this.onReviewPressed,
  });

  @override
  State<_StudentResultRow> createState() => _StudentResultRowState();
}

class _StudentResultRowState extends State<_StudentResultRow> {
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
              baseColor: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MetricCard(
              title: 'Class Average (ĐTB Lớp)',
              value: '${avg.toStringAsFixed(1)} / 100',
              subtitle: 'Average points scored',
              icon: Icons.analytics,
              baseColor: const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MetricCard(
              title: 'Pass Rate (Tỷ lệ đạt)',
              value: '${passRate.toStringAsFixed(1)}%',
              subtitle: '$passCount / $total scored >= 50',
              icon: Icons.check_circle_outline,
              baseColor: const Color(0xFF10B981),
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
  final Color baseColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: baseColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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

    final filterColors = {
      'All': const Color(0xFF6366F1),
      'Excellent': const Color(0xFF10B981),
      'Good': const Color(0xFF0EA5E9),
      'Average': const Color(0xFFF59E0B),
      'Weak': const Color(0xFFEF4444),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.keys.map((filter) {
          final isCurrent = selectedFilter == filter;
          final count = counts[filter] ?? 0;
          final label = labels[filter]!;
          final baseColor = filterColors[filter]!;
          
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          Color chipBg;
          Color textCol;
          Color borderCol;
          
          if (isCurrent) {
            chipBg = baseColor;
            textCol = Colors.white;
            borderCol = baseColor;
          } else {
            chipBg = isDark 
                ? baseColor.withOpacity(0.08) 
                : baseColor.withOpacity(0.06);
            textCol = isDark ? baseColor.withOpacity(0.9) : baseColor;
            borderCol = isDark 
                ? baseColor.withOpacity(0.15) 
                : baseColor.withOpacity(0.12);
          }

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSelected(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderCol, width: 1),
                  boxShadow: isCurrent ? [
                    BoxShadow(
                      color: baseColor.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isCurrent 
                            ? Colors.white.withOpacity(0.2) 
                            : (isDark ? baseColor.withOpacity(0.15) : baseColor.withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : textCol,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ViewHeader(
              title: 'AI Configuration',
              subtitle: 'Check settings, endpoint status, and setup instructions.',
            ),
            const SizedBox(height: 16),
            const SettingsCard(
              title: 'API Endpoint',
              value: 'http://localhost:11434',
              icon: Icons.api,
              cardColor: Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            const SettingsCard(
              title: 'Grading Model',
              value: 'Rubric JSON Parser (Qwen Local Core)',
              icon: Icons.model_training,
              cardColor: Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 16),
            const SettingsCard(
              title: 'Status Connection',
              value: 'Ready to grade • Active server detected',
              icon: Icons.cloud_done,
              cardColor: Color(0xFF10B981),
            ),
            const SizedBox(height: 32),
            Text(
              'Grading Instructions', 
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                '1. Rubric files can be uploaded as .json or Microsoft Word .docx.\n'
                '2. Student solutions files must be uploaded as .txt plain text files.\n'
                '3. Output excel sheet will compile both /100 and standard /10 FPT grading scales.\n'
                '4. Return to "Setup Files" tab to specify your workspaces and launch the AI Grader.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
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
  final Color cardColor;

  const SettingsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: cardColor),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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
