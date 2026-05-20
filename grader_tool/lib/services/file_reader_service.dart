import 'dart:io';

class FileReaderService {
  /// Đọc file .docx (tiêu chí chấm điểm)
  /// Note: docx_to_text có issue trên Windows desktop, nên tạm dùng placeholder
  static Future<String> readDocxFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      // TODO: Cài đặt thích hợp để parse DOCX khi package được fix
      return 'Grading criteria loaded from: ${file.path}';
    } catch (e) {
      throw Exception('Error reading grading criteria: $e');
    }
  }

  /// Đọc file .txt (nội dung bài làm của sinh viên)
  static Future<String> readTxtFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      final text = await file.readAsString();
      return text;
    } catch (e) {
      throw Exception('Error reading student submission: $e');
    }
  }

  /// Lấy danh sách tất cả file .txt trong một thư mục
  static Future<List<FileSystemEntity>> getStudentFiles(
    String folderPath,
  ) async {
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        throw Exception('Folder does not exist: $folderPath');
      }

      final files = folder
          .listSync()
          .where((file) => file.path.endsWith('.txt'))
          .toList();

      files.sort((a, b) => a.path.compareTo(b.path));
      return files;
    } catch (e) {
      throw Exception('Error accessing student files: $e');
    }
  }

  /// Lấy tên file từ đường dẫn
  static String getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
