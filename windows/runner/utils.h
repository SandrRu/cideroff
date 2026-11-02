#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Redirects the process stdout/stderr through a pipe so every message is
// written BOTH to the attached console (if any) and to a log file placed next
// to the executable. This captures native Flutter engine output that never
// reaches Dart (e.g. accessibility_bridge AXTree errors).
// Safe to call once; subsequent calls are no-ops.
void RedirectEngineOutputToConsoleAndFile();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty std::string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty std::vector<std::string> on failure.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
