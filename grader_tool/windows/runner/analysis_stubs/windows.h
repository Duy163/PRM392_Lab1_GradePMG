// Minimal stub of Windows API symbols used by main.cpp for static analysis.
#ifndef ANALYSIS_STUBS_WINDOWS_H
#define ANALYSIS_STUBS_WINDOWS_H

#include <cstddef>
#include <cstdint>

using DWORD = unsigned long;
using BOOL = int;
using HINSTANCE = void*;
using WPARAM = unsigned long;
using LPARAM = long;

struct MSG { void* hwnd; unsigned int message; WPARAM wParam; LPARAM lParam; };

extern "C" BOOL AttachConsole(DWORD dwProcessId);
extern "C" BOOL IsDebuggerPresent();
void CreateAndAttachConsole();
extern "C" int GetMessage(MSG* msg, void* h, unsigned int m1, unsigned int m2);
extern "C" void TranslateMessage(MSG* msg);
extern "C" void DispatchMessage(MSG* msg);
extern "C" long CoInitializeEx(void* pvReserved, unsigned long dwCoInit);
extern "C" void CoUninitialize();
#define COINIT_APARTMENTTHREADED 0x2
#define APIENTRY

#endif  // ANALYSIS_STUBS_WINDOWS_H
