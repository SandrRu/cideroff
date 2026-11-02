#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>
#include <windows.h>

#include <atomic>
#include <string>
#include <thread>

namespace {

std::atomic<bool> g_started{false};

// Path of the engine log file: <dir_of_exe>/cider_off_engine.log
std::wstring EngineLogPath() {
  wchar_t exe_path[MAX_PATH];
  DWORD len = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::wstring path(exe_path, len);
  size_t pos = path.find_last_of(L"\\/");
  if (pos != std::wstring::npos) {
    path = path.substr(0, pos + 1);
  }
  path += L"cider_off_engine.log";
  return path;
}

// Reads everything written into the pipe and duplicates it to the console
// (when attached) and to the log file.
void PumpThread(int read_fd, HANDLE console_handle) {
  FILE* log_file = nullptr;
  std::wstring log_path = EngineLogPath();
  _wfopen_s(&log_file, log_path.c_str(), L"a, ccs=UTF-8");

  char buffer[4096];
  int bytes_read;
  while ((bytes_read = _read(read_fd, buffer, sizeof(buffer))) > 0) {
    if (console_handle != nullptr && console_handle != INVALID_HANDLE_VALUE) {
      DWORD written = 0;
      ::WriteFile(console_handle, buffer, static_cast<DWORD>(bytes_read),
                  &written, nullptr);
    }
    if (log_file != nullptr) {
      fwrite(buffer, 1, static_cast<size_t>(bytes_read), log_file);
      fflush(log_file);
    }
  }

  if (log_file != nullptr) {
    fclose(log_file);
  }
  _close(read_fd);
}

}  // namespace

void RedirectEngineOutputToConsoleAndFile() {
  // Only redirect once.
  if (g_started.exchange(true)) {
    return;
  }

  // Remember the console handles before we steal the std descriptors.
  HANDLE console_handle = ::GetStdHandle(STD_OUTPUT_HANDLE);
  if (console_handle == nullptr || console_handle == INVALID_HANDLE_VALUE) {
    console_handle = ::GetStdHandle(STD_ERROR_HANDLE);
  }

  int pipe_fds[2] = {-1, -1};
  if (_pipe(pipe_fds, 8192, _O_TEXT) != 0) {
    return;
  }

  // Point stdout/stderr (fd 1 and 2) at the write end of the pipe.
  _dup2(pipe_fds[1], 1);
  _dup2(pipe_fds[1], 2);
  _close(pipe_fds[1]);  // Duplicated descriptors keep the pipe open.

  // Let the Flutter engine pick up the new streams.
  FlutterDesktopResyncOutputStreams();

  std::thread([read_fd = pipe_fds[0], console_handle]() {
    PumpThread(read_fd, console_handle);
  }).detach();
}