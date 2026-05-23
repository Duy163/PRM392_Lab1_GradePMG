# Grader Tool

Công cụ chấm điểm tự động sử dụng AI cho bài tập sinh viên.

## Tính năng chính

### 1. Chấm điểm tự động
- Hỗ trợ 2 chế độ chấm điểm:
  - **Advanced AI (Ollama)**: Chấm điểm chính xác cao sử dụng LLM local
  - **Fast Local Grader**: Chấm điểm nhanh dựa trên từ khóa

### 2. Quản lý Rubric
- Hỗ trợ file rubric định dạng:
  - `.docx` - File Word chứa tiêu chí chấm điểm
  - `.json` - File JSON với cấu trúc rubric chi tiết

### 3. Lưu trữ kết quả tự động ⭐ MỚI
- **Tự động lưu kết quả**: Mỗi lần chấm điểm, kết quả sẽ được lưu tự động vào folder `result/`
- **Lưu đầy đủ thông tin**:
  - Thông tin sinh viên
  - Điểm số chi tiết từng yêu cầu
  - Rubric đã sử dụng
  - Nhận xét và feedback
  - Thời gian chấm điểm

### 4. Quản lý file kết quả ⭐ MỚI
- **Tab "Saved Results"** để xem và quản lý các file đã lưu
- **Xem chi tiết**: Click vào file để xem thông tin đầy đủ
- **Xóa file cũ**: Tự động xóa các file kết quả cũ hơn số ngày chỉ định (7, 14, 30, 60, 90 ngày)
- **Xóa từng file**: Xóa file riêng lẻ khi không cần thiết

### 5. Xuất Excel
- Xuất kết quả ra file Excel theo template
- Tự động điền điểm và nhận xét

## Cách sử dụng

### Bước 1: Setup Files
1. Chọn folder chứa bài làm sinh viên (file .txt)
2. Chọn file rubric (.docx hoặc .json)
3. Chọn file Excel template
4. Chọn chế độ chấm điểm
5. Click "Start Grading"

### Bước 2: Review & Export
- Xem danh sách kết quả chấm điểm
- Xem chi tiết từng bài
- Xuất ra Excel

### Bước 3: Saved Results (MỚI!)
- Xem tất cả file kết quả đã lưu trong folder `result/`
- Click "Xem chi tiết" để xem thông tin đầy đủ
- Click "Xóa file cũ" để dọn dẹp file không cần thiết
- Chọn số ngày để xóa file cũ hơn thời gian đó

## Cấu trúc file kết quả

Mỗi file kết quả được lưu với tên: `{tên_sinh_viên}_{timestamp}.json`

Ví dụ: `NguyenVanA_20260523_143025.json`

Nội dung file bao gồm:
```json
{
  "metadata": {
    "graded_at": "2026-05-23T14:30:25.123Z",
    "student_file": "NguyenVanA.txt",
    "rubric_course": "PRM393",
    "rubric_title": "Project Management Exam",
    "total_possible_points": 100
  },
  "rubric": {
    "exam": { ... },
    "requirements": [ ... ]
  },
  "grading_result": {
    "student_file": "NguyenVanA.txt",
    "total_score": 85.5,
    "requirements": [ ... ]
  },
  "summary": {
    "total_score": 85.5,
    "percentage": "85.50",
    "requirements_count": 4,
    "general_feedback": "..."
  }
}
```

## Yêu cầu hệ thống

- Flutter SDK
- Ollama (nếu sử dụng chế độ Advanced AI)
- Windows/macOS/Linux

## Cài đặt

```bash
flutter pub get
flutter run -d windows
```

## Folder Structure

```
grader_tool/
├── lib/
│   ├── models/          # Data models
│   ├── services/        # Business logic
│   ├── views/           # UI screens
│   └── main.dart        # Entry point
├── result/              # Saved grading results (auto-created)
└── README.md
```
