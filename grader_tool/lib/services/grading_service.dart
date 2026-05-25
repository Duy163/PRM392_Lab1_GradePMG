import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/models/rubric.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:grader_tool/services/file_reader_service.dart';
import 'package:grader_tool/services/ollama_service.dart';
import 'package:grader_tool/services/result_storage_service.dart';

class GradingService {
  // Cached rubric to avoid re-reading/parsing DOCX or JSON for each grading run
  static RubricExam? _cachedRubric;
  static String? _cachedRubricPath;

  static Future<List<GradingResult>> gradeAllStudents({
    required String criteriaDocPath,
    String? solutionsFolderPath,
    List<String>? selectedFilePaths,
    required Function(String) onProgress,
    required Function(String) onError,
  }) async {
    final results = <GradingResult>[];

    try {
      onProgress('📖 Reading grading rubric...');

      // Use cached rubric when possible to avoid repeated parsing
      RubricExam rubric;
      if (_cachedRubric != null && _cachedRubricPath == criteriaDocPath) {
        rubric = _cachedRubric!;
        onProgress('♻️ Using cached rubric');
      } else {
        rubric = await _loadRubric(criteriaDocPath);
        _cachedRubric = rubric;
        _cachedRubricPath = criteriaDocPath;
      }
      final rubricContext = OllamaService.buildRubricContext(rubric);

      onProgress('📂 Preparing student submissions...');
      List<String> targetPaths = [];
      if (selectedFilePaths != null && selectedFilePaths.isNotEmpty) {
        targetPaths = selectedFilePaths;
      } else if (solutionsFolderPath != null) {
        final studentFiles = await FileReaderService.getStudentFiles(
          solutionsFolderPath,
        );
        if (studentFiles.isEmpty) {
          onError('❌ No .txt files found in the solutions folder');
          return [];
        }
        targetPaths = studentFiles.map((f) => f.path).toList();
      } else {
        onError('❌ No solutions folder or selected files provided');
        return [];
      }

      onProgress('🎯 Found ${targetPaths.length} student submissions');

      // Load cache file if exists
      String? cacheFolder = solutionsFolderPath;
      if (cacheFolder == null && targetPaths.isNotEmpty) {
        cacheFolder = File(targetPaths.first).parent.path;
      }

      File? cacheFile;
      Map<String, dynamic> cacheData = {};
      if (cacheFolder != null) {
        cacheFile = File(
          '$cacheFolder${Platform.pathSeparator}.grading_cache.json',
        );
        if (await cacheFile.exists()) {
          try {
            final cacheContent = await cacheFile.readAsString();
            cacheData = jsonDecode(cacheContent) as Map<String, dynamic>;
          } catch (_) {
            // Ignore corrupted cache
          }
        }
      }

      // Process grading with moderate concurrency (concurrency = 2) for better throughput
      // Combined with our reduced prompt size, this will be extremely fast and not overload local Ollama.
      const int concurrency = 2;

      // Build a list of job closures so we can run them with worker tasks
      final jobs = <Future<void> Function()>[];
      for (var i = 0; i < targetPaths.length; i++) {
        final path = targetPaths[i];
        final indexDisplay = i + 1;

        jobs.add(() async {
          try {
            final fileName = FileReaderService.getFileName(path);
            final file = File(path);
            final stat = await file.stat();
            final lastModified = stat.modified.millisecondsSinceEpoch;
            final fileSize = stat.size;
            final cacheKey = fileName;

            // Check if cached result is valid
            final cachedEntry = cacheData[cacheKey];
            bool isCacheValid = false;
            Map<String, dynamic>? cachedResult;
            if (cachedEntry != null &&
                cachedEntry['last_modified'] == lastModified &&
                cachedEntry['file_size'] == fileSize &&
                cachedEntry['result'] != null) {
              cachedResult = cachedEntry['result'] as Map<String, dynamic>;
              final feedback =
                  cachedResult['general_feedback']?.toString() ??
                  cachedResult['overall_feedback']?.toString() ??
                  '';
              if (!feedback.contains('Keyword Matcher Fallback') &&
                  !feedback.contains('parsed from DOCX')) {
                isCacheValid = true;
              }
            }

            if (isCacheValid && cachedResult != null) {
              final studentCode = await FileReaderService.readTxtFile(path);
              final gradingResultObj = GradingResult.fromJson(
                fileName,
                studentCode,
                cachedResult,
              );
              results.add(gradingResultObj);

              // Lưu kết quả vào file JSON trong folder result (cả khi load từ cache)
              try {
                await ResultStorageService.saveGradingResult(
                  result: gradingResultObj,
                  rubric: rubric,
                );
              } catch (e) {
                debugPrint('Warning: Failed to save result to file: $e');
              }

              onProgress(
                '♻️ Loaded from Cache ($indexDisplay/${targetPaths.length}): $fileName (Instant)',
              );
              return;
            }

            onProgress(
              '🔄 Grading ($indexDisplay/${targetPaths.length}): $fileName...',
            );

            final studentCode = await FileReaderService.readTxtFile(path);
            final gradeResult = await OllamaService.gradeAssignment(
              rubric: rubric,
              studentCode: studentCode,
              rubricContext: rubricContext,
            );

            if (gradeResult['success'] == true) {
              final jsonResult = gradeResult['json'] as Map<String, dynamic>;
              final gradingResultObj = GradingResult.fromJson(
                fileName,
                studentCode,
                jsonResult,
              );
              results.add(gradingResultObj);

              // Lưu kết quả vào file JSON trong folder result
              try {
                await ResultStorageService.saveGradingResult(
                  result: gradingResultObj,
                  rubric: rubric,
                );
              } catch (e) {
                debugPrint('Warning: Failed to save result to file: $e');
              }

              // Save to cache map
              cacheData[cacheKey] = {
                'last_modified': lastModified,
                'file_size': fileSize,
                'result': jsonResult,
              };

              onProgress(
                '✅ Graded $fileName - Score: ${gradingResultObj.score.toStringAsFixed(1)}/100',
              );
            } else {
              onError('⚠️ Failed to grade $fileName: ${gradeResult['error']}');
              results.add(
                GradingResult(
                  studentFile: fileName,
                  submissionContent: studentCode,
                  requirements: [],
                  totalScore: null,
                  feedback: 'Error: ${gradeResult['error']}',
                  fullResponse: '',
                ),
              );
            }
          } catch (e) {
            onError('Error grading $path: $e');
          }
        });
      }

      var nextJob = 0;
      final workerCount = min(concurrency, jobs.length);
      final workers = List<Future<void>>.generate(workerCount, (_) async {
        while (true) {
          final jobIndex = nextJob;
          if (jobIndex >= jobs.length) break;
          nextJob += 1;
          await jobs[jobIndex]();
        }
      });

      try {
        await Future.wait(workers);
      } catch (_) {
        // Individual job errors are reported via onError; swallow here
      }

      // Save cache back to disk
      if (cacheFile != null) {
        try {
          await cacheFile.writeAsString(jsonEncode(cacheData));
        } catch (_) {
          // ignore cache write errors
        }
      }

      onProgress(
        '✨ Grading complete! ${results.length} submissions processed.',
      );
      return results;
    } catch (e) {
      onError('Fatal error during grading process: $e');
      return [];
    }
  }

  static Future<RubricExam> _loadRubric(String path) async {
    debugPrint('\n=== LOADING RUBRIC ===');
    debugPrint('File path: $path');
    debugPrint('File extension: ${path.toLowerCase().split('.').last}');

    if (path.toLowerCase().endsWith('.json')) {
      debugPrint('Loading from JSON file...');
      final rubric = await FileReaderService.readRubricJsonFile(path);
      debugPrint(
        '✓ Loaded ${rubric.requirements.length} requirements from JSON:',
      );
      for (final req in rubric.requirements) {
        debugPrint(
          '  - ${req.id}: ${req.name} (${req.criteria.length} criteria, ${req.maxPoints} points)',
        );
      }
      return rubric;
    }

    // DOCX fallback: parse text and try to infer the rubric structure if needed.
    debugPrint('Loading from DOCX file...');
    final text = await FileReaderService.readDocxFile(path);
    final jsonRubric = _parseDocxTextToRubric(text);
    final rubric = RubricExam.fromJson(jsonRubric);
    debugPrint(
      '✓ Parsed ${rubric.requirements.length} requirements from DOCX:',
    );
    for (final req in rubric.requirements) {
      debugPrint(
        '  - ${req.id}: ${req.name} (${req.criteria.length} criteria, ${req.maxPoints} points)',
      );
    }
    return rubric;
  }

  static Map<String, dynamic> _parseDocxTextToRubric(String text) {
    debugPrint(
      '\n=== DEBUG: Parsing DOCX to Rubric (Robust Section-Based) ===',
    );
    debugPrint('Text length: ${text.length}');

    // Normalize line endings and double spaces
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r' {2,}'), ' ');

    // Split by Yêu cầu headers
    final reqRegExp = RegExp(
      r'(?=Yêu\s+cầu\s+\d+|Requirement\s+\d+)',
      caseSensitive: false,
    );
    final parts = normalized.split(reqRegExp);

    final requirements = <Map<String, dynamic>>[];
    double totalExamPoints = 0.0;

    // Part 0 is overview, we can try to extract course/title
    String course = 'PMG201c';
    String title = 'Practical Exam';
    if (parts.isNotEmpty) {
      final firstLines = parts[0]
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (firstLines.isNotEmpty) {
        title = firstLines[0];
        final courseMatch = RegExp(r'^([A-Z0-9a-z]+)').firstMatch(title);
        if (courseMatch != null) {
          course = courseMatch.group(1)!;
        }
      }
    }

    // Parse each Yêu cầu section
    for (var i = 1; i < parts.length; i++) {
      final sectionText = parts[i];
      final lines = sectionText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final headerLine = lines[0];
      final reqMatch = RegExp(
        r'(?:Yêu\s+cầu|Requirement)\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(headerLine);
      if (reqMatch == null) continue;

      final reqNum = reqMatch.group(1)!;
      final reqId = 'YC$reqNum';

      // Find where "Bảng tiêu chí chấm điểm" or "Rubric" starts
      int rubricStartIndex = -1;
      for (var j = 0; j < lines.length; j++) {
        if (lines[j].toLowerCase().contains('bảng tiêu chí chấm điểm') ||
            lines[j].toLowerCase().contains('rubric')) {
          rubricStartIndex = j;
          break;
        }
      }

      // Find where "Lỗi thường gặp" or "Common mistakes" starts
      int mistakesStartIndex = -1;
      for (var j = 0; j < lines.length; j++) {
        if (lines[j].toLowerCase().contains('lỗi thường gặp') ||
            lines[j].toLowerCase().contains('common mistakes')) {
          mistakesStartIndex = j;
          break;
        }
      }

      // Extract first pass criteria list (names and max points)
      final criteriaList = <Map<String, dynamic>>[];
      final criteriaMap = <String, Map<String, dynamic>>{};

      Map<String, dynamic> buildLevels({
        String? fullDesc,
        String? partialDesc,
        String? failDesc,
      }) {
        return {
          'full': {
            'score_range': '100%',
            'description': fullDesc ?? 'Đạt đầy đủ yêu cầu',
          },
          'partial': {
            'score_range': '50-70%',
            'description': partialDesc ?? 'Đạt một phần yêu cầu',
          },
          'fail': {
            'score_range': '<50%',
            'description': failDesc ?? 'Chưa đạt yêu cầu',
          },
        };
      }

      // Parse criteria from the first part of the section (before Rubric table)
      int criteriaEndIndex = lines.length;
      if (rubricStartIndex != -1) {
        criteriaEndIndex = rubricStartIndex;
      } else if (mistakesStartIndex != -1) {
        criteriaEndIndex = mistakesStartIndex;
      }
      for (var j = 1; j < criteriaEndIndex; j++) {
        final line = lines[j];

        // Match ID like "1.1" or "1.1." at start of line
        final idMatch = RegExp(r'^(\d+)\.(\d+)\.?\s+(.+)$').firstMatch(line);
        if (idMatch != null) {
          final major = idMatch.group(1)!;
          final minor = idMatch.group(2)!;
          final cid = '$major.$minor';
          final cname = idMatch.group(3)!.trim();

          // The points should be on the next line or in this line
          double points = 0.0;
          final pointsMatch = RegExp(
            r'(\d+(?:\.\d+)?)\s*(?:điểm|đ|points?|pts?)',
            caseSensitive: false,
          ).firstMatch(cname);
          if (pointsMatch != null) {
            points = double.parse(pointsMatch.group(1)!);
          } else if (j + 1 < criteriaEndIndex) {
            final nextLine = lines[j + 1];
            final nextPointsMatch = RegExp(
              r'^(\d+(?:\.\d+)?)\s*(?:điểm|đ|points?|pts?)$',
              caseSensitive: false,
            ).firstMatch(nextLine);
            if (nextPointsMatch != null) {
              points = double.parse(nextPointsMatch.group(1)!);
              j++; // Consume next line
            }
          }

          final criterion = {
            'id': cid,
            'name': '$cid $cname',
            'max_points': points,
            'levels': {
              'full': {
                'score_range': '100%',
                'description': 'Đạt đầy đủ yêu cầu',
              },
              'partial': {
                'score_range': '50-70%',
                'description': 'Đạt một phần yêu cầu',
              },
              'fail': {
                'score_range': '<50%',
                'description': 'Chưa đạt yêu cầu',
              },
            },
          };
          criteriaList.add(criterion);
          criteriaMap[cid] = criterion;
        }
      }

      // Parse detailed rubric table if exists
      if (rubricStartIndex != -1) {
        final rubricEndIndex = mistakesStartIndex != -1
            ? mistakesStartIndex
            : lines.length;

        // Skip the headers of the rubric table (e.g. Tiêu chí đánh giá, Điểm, Đạt đầy đủ...)
        int j = rubricStartIndex + 1;
        while (j < rubricEndIndex) {
          final line = lines[j];

          // Match a criterion ID like "1.1" or "1.1." at start
          final cidMatch = RegExp(r'^(\d+)\.(\d+)\.?\s*(.*)$').firstMatch(line);
          if (cidMatch != null) {
            final major = cidMatch.group(1)!;
            final minor = cidMatch.group(2)!;
            final cid = '$major.$minor';
            final cname = cidMatch.group(3)!.trim();

            // Let's parse the next lines for points, full, partial, fail descriptions
            // Look ahead up to 4 lines
            double points = 0.0;
            String? fullDesc;
            String? partialDesc;
            String? failDesc;

            int step = 0;
            int k = j + 1;
            while (k < rubricEndIndex && step < 4) {
              final l = lines[k];
              // If we hit another criterion ID, stop
              if (RegExp(r'^\d+\.\d+\.?\s+').hasMatch(l)) {
                break;
              }

              if (step == 0) {
                // Should be points (e.g. "2 đ" or "2 điểm")
                final pMatch = RegExp(
                  r'^(\d+(?:\.\d+)?)\s*(?:đ|điểm|points?|pts?)$',
                  caseSensitive: false,
                ).firstMatch(l);
                if (pMatch != null) {
                  points = double.parse(pMatch.group(1)!);
                } else {
                  // If it doesn't match points, maybe points was already on the ID line, treat this as fullDesc
                  fullDesc = l;
                  step = 1;
                }
              } else if (step == 1) {
                fullDesc = l;
              } else if (step == 2) {
                partialDesc = l;
              } else if (step == 3) {
                failDesc = l;
              }
              step++;
              k++;
            }

            // Update j to k-1 so we don't re-process these lines
            j = k - 1;

            // Update the criterion in our map or add it
            final existing = criteriaMap[cid];
            if (existing != null) {
              if (cname.isNotEmpty &&
                  !existing['name'].toString().contains(cname)) {
                existing['name'] = '$cid $cname';
              }
              if (points > 0) {
                existing['max_points'] = points;
              }
              existing['levels'] = buildLevels(
                fullDesc: fullDesc,
                partialDesc: partialDesc,
                failDesc: failDesc,
              );
            } else {
              final criterion = {
                'id': cid,
                'name': '$cid ${cname.isEmpty ? cid : cname}',
                'max_points': points,
                'levels': buildLevels(
                  fullDesc: fullDesc,
                  partialDesc: partialDesc,
                  failDesc: failDesc,
                ),
              };
              criteriaList.add(criterion);
              criteriaMap[cid] = criterion;
            }
          }
          j++;
        }
      }

      // Parse common mistakes
      final commonMistakes = <String>[];
      if (mistakesStartIndex != -1) {
        for (var j = mistakesStartIndex + 1; j < lines.length; j++) {
          final line = lines[j];
          if (line.startsWith('•') ||
              line.startsWith('-') ||
              line.startsWith('*')) {
            final mistake = line.replaceFirst(RegExp(r'^[\s•\-*]+'), '').trim();
            if (mistake.isNotEmpty) {
              commonMistakes.add(mistake);
            }
          } else if (line.isNotEmpty && !line.contains(':')) {
            commonMistakes.add(line);
          }
        }
      }

      // Calculate total points for this requirement
      if (criteriaList.isEmpty) continue;

      double reqPoints = criteriaList.fold<double>(
        0.0,
        (sum, c) => sum + (c['max_points'] as double),
      );
      totalExamPoints += reqPoints;

      requirements.add({
        'id': reqId,
        'name': headerLine,
        'max_points': reqPoints,
        'criteria': criteriaList,
        'common_mistakes': commonMistakes,
      });
    }

    if (requirements.isEmpty) {
      debugPrint(
        '⚠️ Rubric parsing found no requirements. Falling back to default rubric.',
      );
      return _createDefaultRubric();
    }

    debugPrint(
      '✓ Successfully parsed ${requirements.length} requirements. Total points: $totalExamPoints',
    );
    return {
      'exam': {
        'course': course,
        'title': title,
        'total_points': totalExamPoints,
        'grading_scale_note':
            'Đạt đầy đủ (100%), Chấp nhận được (50-70%), Chưa đạt (<50%)',
      },
      'requirements': requirements,
    };
  }

  static Map<String, dynamic> _createDefaultRubric() {
    debugPrint('Creating default rubric with YC1 structure...');
    return {
      'exam': {
        'course': 'PRM393',
        'title': 'Project Management Exam',
        'total_points': 20,
        'grading_scale_note': 'Default rubric',
      },
      'requirements': [
        {
          'id': 'YC1',
          'name':
              'Yêu cầu 1 – Phát biểu điều lệ dự án (Project Charter Statement)',
          'max_points': 20.0,
          'criteria': [
            {
              'id': '1.1',
              'name': '1.1 Tên dự án rõ ràng và phù hợp',
              'max_points': 2.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description':
                      'Tên đầy đủ, rõ ràng, phản ánh đúng bản chất dự án',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Tên có nhưng còn chung chung',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Không có tên hoặc tên không liên quan',
                },
              },
            },
            {
              'id': '1.2',
              'name': '1.2 Lý do triển khai (vấn đề / cơ hội)',
              'max_points': 4.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Nêu rõ ít nhất 2 lý do cụ thể',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Nêu được 1 lý do hoặc còn mơ hồ',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Không nêu lý do',
                },
              },
            },
            {
              'id': '1.3',
              'name': '1.3 Mục đích dự án (mong đợi đạt được)',
              'max_points': 4.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Phát biểu rõ kết quả mong muốn',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Có mục đích nhưng thiếu yếu tố',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Mục đích mơ hồ',
                },
              },
            },
            {
              'id': '1.4',
              'name': '1.4 Ràng buộc phạm vi (Scope constraint)',
              'max_points': 3.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Chỉ rõ trong và ngoài phạm vi',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Nêu phạm vi nhưng không phân biệt',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Phạm vi quá rộng',
                },
              },
            },
            {
              'id': '1.5',
              'name': '1.5 Ràng buộc thời gian (Time constraint)',
              'max_points': 3.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Thời hạn cụ thể',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Có hạn chót nhưng không rõ',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Không có thông tin thời gian',
                },
              },
            },
            {
              'id': '1.6',
              'name': '1.6 Ràng buộc chi phí (Cost constraint)',
              'max_points': 2.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Nêu đúng ngân sách',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Có ngân sách nhưng không chính xác',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Không có thông tin chi phí',
                },
              },
            },
            {
              'id': '1.7',
              'name': '1.7 Ràng buộc chất lượng (Quality constraint)',
              'max_points': 2.0,
              'levels': {
                'full': {
                  'score_range': '100%',
                  'description': 'Nêu ít nhất 1 chỉ tiêu đo lường được',
                },
                'partial': {
                  'score_range': '50-70%',
                  'description': 'Có đề cập nhưng không đo lường được',
                },
                'fail': {
                  'score_range': '<50%',
                  'description': 'Không đề cập chất lượng',
                },
              },
            },
          ],
          'common_mistakes': [
            'Viết charter dưới dạng bullet list ngắn',
            'Lẫn lộn Justification với Objective',
            'Ràng buộc chất lượng bị bỏ qua',
            'Không sử dụng con số cụ thể',
          ],
        },
      ],
    };
  }
}
