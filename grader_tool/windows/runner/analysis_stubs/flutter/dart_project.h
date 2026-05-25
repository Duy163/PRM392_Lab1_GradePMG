// Minimal stub for static analysis when Flutter headers aren't available.
#ifndef ANALYSIS_STUBS_FLUTTER_DART_PROJECT_H
#define ANALYSIS_STUBS_FLUTTER_DART_PROJECT_H

// cppcheck-suppress missingIncludeSystem
#include <string>
// cppcheck-suppress missingIncludeSystem
#include <vector>

namespace flutter {

class DartProject {
 public:
  explicit DartProject(const wchar_t*) {}
  void set_dart_entrypoint_arguments(std::vector<std::string>) {}
};

}  // namespace flutter

#endif  // ANALYSIS_STUBS_FLUTTER_DART_PROJECT_H
