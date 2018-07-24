// Copyright 2013-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
// Written by hand from documentation.
/*!
 * Windows bindings.
 *
 * As it stands, this module only has the bits of WIN32 that have been used.
 * Pull requests to add more welcome.
 *
 * @ingroup cbind
 * @ingroup winbind
 */
module core.c.windows.windows;

version (Windows):



import core.c.stdarg;


extern (Windows):

alias UINT = u32;
alias WORD = u16;
alias DWORD = u32;
alias DWORD64 = u64;
alias PDWORD64 = DWORD64*;
alias BOOL = i32;
alias BYTE = u8;
alias LPBYTE = i8*;
alias PVOID = void*;
alias LPVOID = void*;
alias LPCVOID = const(void)*;
alias LPCSTR = const(char)*;
alias LPCWSTR = const(wchar)*;
alias LPBOOL = BOOL*;
alias LPSTR = char*;
alias LPWSTR = wchar*;
alias LPDWORD = DWORD*;
alias ULONG_PTR = size_t;
alias DWORD_PTR = ULONG_PTR;
alias HANDLE = PVOID;
alias PHANDLE = HANDLE*;
alias HINSTANCE = HANDLE;
alias HMODULE = HINSTANCE;
alias HDC = HANDLE;
alias HWND = HANDLE;
alias HLOCAL = HANDLE;
alias TCHAR = char;
alias ULONG = u32;
alias LONG = i32;
alias ULONG64 = u64;
alias LONG_PTR = LONG*;
alias UINT_PTR = UINT*;
alias WPARAM = UINT_PTR;
alias LPARAM = LONG_PTR;
alias LRESULT = LONG_PTR;
alias HICON = HANDLE;
alias HCURSOR = HICON;
alias HBRUSH = HANDLE;
alias ATOM = WORD;
alias HMENU = HANDLE;
alias PROC = void*;  // This is a guess.
alias SHORT = i16;
alias LARGE_INTEGER = i64;
alias SIZE_T = size_t;
alias HKEY = HANDLE;
alias PHKEY = HKEY*;
alias LONGLONG = i64;
alias ULONGLONG = u64;

struct M128A
{
	Low: ULONGLONG;
	High: LONGLONG;
}


enum TRUE = 1;
enum FALSE = 0;
enum MAX_PATH = 260;
enum INVALID_HANDLE_VALUE = -1;

struct SECURITY_ATTRIBUTES
{
	nLength: DWORD;
	lpSecurityDescriptor: LPVOID;
	bInheritHandle: BOOL;
}

alias PSECURITY_ATTRIBUTES = SECURITY_ATTRIBUTES*;
alias LPSECURITY_ATTRIBUTES = SECURITY_ATTRIBUTES*;

enum STARTF_USESTDHANDLES = 0x00000100;

struct STARTUPINFOA
{
	cb: DWORD;
	lpReserved: LPSTR;
	lpDesktop: LPSTR;
	lpTitle: LPSTR;
	dwX: DWORD;
	dwY: DWORD;
	dwXSize: DWORD;
	dwYSize: DWORD;
	dwXCountChars: DWORD;
	dwYCountChars: DWORD;
	dwFillFlags: DWORD;
	dwFlags: DWORD;
	wShowWindow: WORD;
	cbReserved2: WORD;
	lpReserved2: LPBYTE;
	hStdInput: HANDLE;
	hStdOutput: HANDLE;
	hStdError: HANDLE;
}

alias LPSTARTUPINFOA = STARTUPINFOA*;

struct STARTUPINFOW
{
	cb: DWORD;
	lpReserved: LPWSTR;
	lpDesktop: LPWSTR;
	lpTitle: LPWSTR;
	dwX: DWORD;
	dwY: DWORD;
	dwXSize: DWORD;
	dwYSize: DWORD;
	dwXCountChars: DWORD;
	dwYCountChars: DWORD;
	dwFillFlags: DWORD;
	dwFlags: DWORD;
	wShowWindow: WORD;
	cbReserved2: WORD;
	lpReserved2: LPBYTE;
	hStdInput: HANDLE;
	hStdOutput: HANDLE;
	hStdError: HANDLE;
}

alias LPSTARTUPINFOW = STARTUPINFOW*;

struct PROCESS_INFORMATION
{
	hProcess: HANDLE;
	hThread: HANDLE;
	dwProcessId: DWORD;
	dwThreadId: DWORD;
}

alias LPPROCESS_INFORMATION = PROCESS_INFORMATION*;

fn CreateDirectoryA(LPCSTR, LPSECURITY_ATTRIBUTES) BOOL;
fn CreateDirectoryW(LPCWSTR, LPSECURITY_ATTRIBUTES) BOOL;

fn GetLastError() DWORD;

enum FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100;
enum FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000;
enum FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200;
enum FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800;

fn FormatMessageA(DWORD, LPCVOID, DWORD, DWORD, LPCSTR, DWORD, va_list*) DWORD;
fn FormatMessageW(DWORD, LPCVOID, DWORD, DWORD, LPCWSTR, DWORD, va_list*) DWORD;

fn CreateProcessA(LPCSTR, LPSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCSTR, LPSTARTUPINFOA, LPPROCESS_INFORMATION) BOOL;
fn CreateProcessW(LPCWSTR, LPWSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCWSTR, LPSTARTUPINFOW, LPPROCESS_INFORMATION) BOOL;

enum MAXIMUM_WAIT_OBJECTS = 64;
enum WAIT_OBJECT_0 = 0L;
enum WAIT_IO_COMPLETION = 0x000000C0L;
enum WAIT_ABANDONED = 0x00000080L;
enum WAIT_TIMEOUT   = 0x00000102L;
enum WAIT_FAILED    = 0xFFFFFFFF;
enum DWORD INFINITE = 4294967295L;

fn WaitForSingleObject(HANDLE, DWORD) DWORD;
fn WaitForMultipleObjects(DWORD, HANDLE*, BOOL, DWORD) DWORD;
fn WaitForMultipleObjectsEx(DWORD, HANDLE*, BOOL, DWORD, BOOL) DWORD;
fn CloseHandle(HANDLE) BOOL;
fn GetExitCodeProcess(HANDLE, LPDWORD) BOOL;



enum STILL_ACTIVE = 259;

enum HANDLE_FLAG_INHERIT = 0x00000001;
enum HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x00000002;

fn GetHandleInformation(HANDLE, LPDWORD) BOOL;
fn SetHandleInformation(HANDLE, DWORD, DWORD) BOOL;

enum DWORD STD_INPUT_HANDLE = cast(DWORD) -10;
enum DWORD STD_OUTPUT_HANDLE = cast(DWORD) -11;
enum DWORD STD_ERROR_HANDLE = cast(DWORD) -12;

fn GetStdHandle(DWORD) HANDLE;

fn CreatePipe(PHANDLE, PHANDLE, LPSECURITY_ATTRIBUTES, DWORD) BOOL;

fn CreateNamedPipeA(LPCSTR, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, LPSECURITY_ATTRIBUTES) HANDLE;
fn CreateNamedPipeW(LPCWSTR, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, LPSECURITY_ATTRIBUTES) HANDLE;
fn PeekNamedPipe(HANDLE, LPVOID, DWORD, LPDWORD, LPDWORD, LPDWORD) BOOL;
fn GetOverlappedResult(HANDLE, LPOVERLAPPED, LPDWORD, BOOL) BOOL;

enum DWORD PIPE_ACCESS_DUPLEX   = 0x00000003;
enum DWORD PIPE_ACCESS_INBOUND  = 0x00000001;
enum DWORD PIPE_ACCESS_OUTBOUND = 0x00000002;

enum DWORD FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000;
enum DWORD FILE_FLAG_WRITE_THROUGH       = 0x80000000;
enum DWORD FILE_FLAG_OVERLAPPED          = 0x40000000;
enum DWORD FILE_FLAG_DELETE_ON_CLOSE     = 0x04000000;

enum DWORD WRITE_DAC              = 0x00040000L;
enum DWORD WRITE_OWNER            = 0x00080000L;
enum DWORD ACCESS_SYSTEM_SECURITY = 0x01000000L;

enum DWORD PIPE_TYPE_BYTE        = 0x00000000;
enum DWORD PIPE_TYPE_MESSAGE     = 0x00000004;
enum DWORD PIPE_READMODE_BYTE    = 0x00000000;
enum DWORD PIPE_READMODE_MESSAGE = 0x00000002;

enum DWORD PIPE_WAIT   = 0x00000000;
enum DWORD PIPE_NOWAIT = 0x00000001;

enum DWORD PIPE_ACCEPT_REMOTE_CLIENTS = 0x00000000;
enum DWORD PIPE_REJECT_REMOTE_CLIENTS = 0x00000008;

enum DWORD PIPE_UNLIMITED_INSTANCES = 255;

fn CreateFileA(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE) HANDLE;
fn CreateFileW(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE) HANDLE;

enum DWORD CREATE_ALWAYS = 2;
enum DWORD CREATE_NEW = 1;
enum DWORD OPEN_ALWAYS = 4;
enum DWORD OPEN_EXISTING = 3;
enum DWORD TRUNCATE_EXISTING = 5;

enum DWORD GENERIC_READ    = 0x80000000;
enum DWORD GENERIC_WRITE   = 0x40000000;
enum DWORD GENERIC_EXECUTE = 0x20000000;

enum DWORD FILE_ATTRIBUTE_ARCHIVE   = 0x00000020;
enum DWORD FILE_ATTRIBUTE_ENCRYPTED = 0x00004000;
enum DWORD FILE_ATTRIBUTE_HIDDEN    = 0x00000002;
enum DWORD FILE_ATTRIBUTE_NORMAL    = 0x00000080;
enum DWORD FILE_ATTRIBUTE_OFFLINE   = 0x00001000;
enum DWORD FILE_ATTRIBUTE_READONLY  = 0x00000001;
enum DWORD FILE_ATTRIBUTE_SYSTEM    = 0x00000004;
enum DWORD FILE_ATTRIBUTE_TEMPORARY = 0x00000100;

fn SetPriorityClass(HANDLE, DWORD) BOOL;

enum DWORD ABOVE_NORMAL_PRIORITY_CLASS = 0x00008000;
enum DWORD BELOW_NORMAL_PRIORITY_CLASS = 0x00004000;
enum DWORD HIGH_PRIORITY_CLASS = 0x00000080;
enum DWORD IDLE_PRIORITY_CLASS = 0x00000040;
enum DWORD NORMAL_PRIORITY_CLASS = 0x00000020;
enum DWORD PROCESS_MODE_BACKGROUND_BEGIN = 0x00100000;
enum DWORD PROCESS_MODE_BACKGROUND_END = 0x00200000;
enum DWORD REALTIME_PRIORITY_CLASS = 0x00000100;

fn GetCurrentProcess() HANDLE;
fn GetCurrentProcessId() DWORD;

struct OVERLAPPED
{
	private struct _s
	{
		Offset: DWORD;
		OffsetHigh: DWORD;
	}
	Internal: ULONG_PTR;
	InternalHigh: ULONG_PTR;
	union _u 
	{
		s: _s;
		Pointer: PVOID;
	}
	u: _u;
	hEvent: HANDLE;
}

alias LPOVERLAPPED = OVERLAPPED*;

alias LPOVERLAPPED_COMPLETION_ROUTINE = fn!Windows(DWORD, DWORD, LPOVERLAPPED);

fn ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED) BOOL;
fn ReadFileEx(HANDLE, LPVOID, DWORD, LPOVERLAPPED, LPOVERLAPPED_COMPLETION_ROUTINE) BOOL;
fn WriteFile(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED) BOOL;

struct SYSTEM_INFO
{
	union _u {
		dwOemId: DWORD;
		struct _s {
			wProcessorArchitecture: WORD;
			wReserved: WORD;
		}
		s: _s;
	}
	u: _u;
	dwPageSize: DWORD;
	lpMinimumApplicationAddress: LPVOID;
	lpMaximumApplicationAddress: LPVOID;
	dwActiveProcessorMask: DWORD_PTR;
	dwNumberOfProcessors: DWORD;
	dwProcessorType: DWORD;
	dwAllocationGranularity: DWORD;
	wProcessorLevel: WORD;
	wProcessorRevision: WORD;
}

alias LPSYSTEM_INFO = SYSTEM_INFO*;

fn GetSystemInfo(LPSYSTEM_INFO);

extern (C) fn _fileno(void*) i32;
extern (C) fn _get_osfhandle(i32) HANDLE;
extern(C) fn _fullpath(char*, const(char)*, length: size_t) char*;
extern(C) fn _wfullpath(wchar*, const(wchar)*, length: size_t) char*;

fn PathIsRelativeA(LPCSTR) BOOL;
fn PathIsRelativeW(LPCWSTR) BOOL;

fn Sleep(DWORD);
fn SleepEx(DWORD, BOOL) DWORD;

struct FILETIME
{
	dwLowDateTime: DWORD;
	DWORD dwHighDateTime;
}

alias PFILETIME = FILETIME*;

struct WIN32_FIND_DATA
{
	dwFileAttributes: DWORD;
	ftCreationTime: FILETIME;
	ftLastAccessTime: FILETIME;
	ftLastWriteTime: FILETIME;
	nFileSizeHigh: DWORD;
	nFileSizeLow: DWORD;
	dwReserved0: DWORD;
	dwReserved1: DWORD;
	cFileName: TCHAR[260];
	cAlternateFileName: TCHAR[14];
}

alias LPWIN32_FIND_DATA = WIN32_FIND_DATA*;

enum ERROR_SUCCESS = 0;
enum ERROR_FILE_NOT_FOUND = 2;
enum ERROR_ACCESS_DENIED = 5;
enum ERROR_NO_MORE_FILES = 18;
enum ERROR_INVALID_PARAMETER = 87;
enum ERROR_BROKEN_PIPE = 109;
enum ERROR_NO_DATA = 232;
enum ERROR_MORE_DATA = 234;
enum ERROR_NO_MORE_ITEMS = 259;
enum ERROR_IO_PENDING = 997;

fn FindFirstFileA(LPCSTR, LPWIN32_FIND_DATA) HANDLE;
fn FindFirstFileW(LPCWSTR, LPWIN32_FIND_DATA) HANDLE;
fn FindNextFileA(HANDLE, LPWIN32_FIND_DATA) BOOL;
fn FindNextFileW(HANDLE, LPWIN32_FIND_DATA) BOOL;

fn GetCurrentDirectoryA(DWORD, LPSTR) DWORD;
fn GetCurrentDirectoryW(DWORD, LPWSTR) DWORD;
fn SetCurrentDirectoryA(LPCSTR) BOOL;
fn SetCurrentDirectoryW(LPCWSTR) BOOL;



enum GET_FILEEX_INFO_LEVELS
{
	GetFileExInfoStandard
}

struct WIN32_FILE_ATTRIBUTE_DATA
{
	dwFileAttributes: DWORD;
	ftCreationTime: FILETIME;
	ftLastAccessTime: FILETIME;
	ftLastWriteTime: FILETIME;
	nFileSizeHigh: DWORD;
	nFileSizeLow: DWORD;
}

alias LPWIN32_FILE_ATTRIBUTE_DATA = WIN32_FILE_ATTRIBUTE_DATA*;

enum DWORD FILE_ATTRIBUTE_DIRECTORY = 0x10;
enum INVALID_FILE_ATTRIBUTES = cast(DWORD)-1;

fn GetFileAttributesA(LPCSTR) DWORD;
fn GetFileAttributesW(LPCWSTR) DWORD;
fn GetFileAttributesExA(LPCSTR, GET_FILEEX_INFO_LEVELS, LPVOID) BOOL;
fn GetFileAttributesExW(LPCWSTR, GET_FILEEX_INFO_LEVELS, LPVOID) BOOL;

fn GetFileSize(HANDLE, LPDWORD) DWORD;


fn GetEnvironmentStringsA() LPCSTR;
fn GetEnvironmentStringsW() LPCWSTR;
fn FreeEnvironmentStringsA(LPCSTR) BOOL;
fn FreeEnvironmentStringsW(LPCWSTR) BOOL;


enum uint CP_UTF8 = 65001;

fn MultiByteToWideChar(CodePage: UINT, dwFlags: DWORD, lpMultiByteStr: LPCSTR,
	cbMultiByte: i32, lpWideCharStr: LPWSTR, cchWideChar: i32) i32;
fn WideCharToMultiByte(CodePage: UINT, dwFlags: DWORD, lpWideCharStr: LPCWSTR,
	cchWideChar: i32, lpMultiByteStr: LPSTR, cbMultiByte: i32,
	lpDefaultChar: LPCSTR, lpUsedDefaultChar: LPBOOL) i32;

enum i32 CCHDEVICENAME = 32;
enum i32 CCHFORMNAME = 32;

struct POINTL
{
	x: LONG;
	y: LONG;
}
alias POINT = POINTL;
alias PPOINT = POINT*;
alias PPOINTL = POINTL*;

enum DWORD DM_BITSPERPEL = 0x00040000;
enum DWORD DM_PELSWIDTH  = 0x00080000;
enum DWORD DM_PELSHEIGHT = 0x00100000;

// TODO: In Windows 2000 and older, this structure is different.
struct _devicemode {
	dmDeviceName: TCHAR[32/*CCHDEVICENAME*/];
	dmSpecVersion: WORD;
	dmDriverVersion: WORD;
	dmSize: WORD;
	dmDriverExtra: WORD;
	dmFields: DWORD;

	union _u {
		struct _s {
			dmOrientation: i16;
			dmPaperSize: i16;
			dmPaperLength: i16;
			dmPaperWidth: i16;
			dmScale: i16;
			dmCopies: i16;
			dmDefaultSource: i16;
			dmPrintQuality: i16;
		}
		s: _s;
		struct _s2 {
			dmPosition: POINTL;
			dmDisplayOrientation: DWORD;
			dmDisplayFixedOutput: DWORD;
		}
		s2: _s2;
	}
	u: _u;

	dmColor: i16;
	dmDuplex: i16;
	dmYResolution: i16;
	dmTTOption: i16;
	dmCollate: i16;
	dmFormName: TCHAR[32/*CCHFORMNAME*/];
	dmLogPixels: WORD;
	dmBitsPerPel: DWORD;
	dmPelsWidth: DWORD;
	dmPelsHeight: DWORD;
	union _u2 {
		dmDisplayFlags: DWORD;
		dmNup: DWORD;
	}
	u2: _u2;
	dmDisplayFrequency: DWORD;
	dmICMMethod: DWORD;
	dmICMIntent: DWORD;
	dmMediaType: DWORD;
	dmDitherType: DWORD;
	dmReserved1: DWORD;
	dmReserved2: DWORD;
	dmPanningWidth: DWORD;
	dmPanningHeight: DWORD;
}
alias DEVMODE = _devicemode;
alias PDEVMODE = _devicemode*;
alias LPDEVMODE = _devicemode*;

enum DWORD CDS_FULLSCREEN = 0x00000004;
enum LONG DISP_CHANGE_SUCCESSFUL = 0;

fn ChangeDisplaySettingsA(lpDevMode: DEVMODE*, dwFlags: DWORD) LONG;
fn ChangeDisplaySettingsW(lpDevMode: DEVMODE*, dwFlags: DWORD) LONG;

fn ShowCursor(bShow: BOOL) i32;

enum u32 MB_ABORTRETRYIGNORE = 0x2;
enum u32 MB_CANCELTRYCONTINUE = 0x6;
enum u32 MB_HELP = 0x4000;
enum u32 MB_OK = 0;
enum u32 MB_OKCANCEL = 0x1;
enum u32 MB_RETRYCANCEL = 0x5;
enum u32 MB_YESNO = 0x4;
enum u32 MB_YESNOCANCEL = 0x3;
enum u32 MB_ICONEXCLAMATION = 0x30;
enum u32 MB_ICONWARNING = 0x30;
enum u32 MB_ICONINFORMATION = 0x40;
enum u32 MB_ICONASTERISK = 0x40;
enum u32 MB_ICONQUESTION = 0x20;
enum u32 MB_ICONSTOP = 0x10;
enum u32 MB_ICONERROR = 0x10;
enum u32 MB_ICONHAND = 0x10;

enum i32 IDYES = 6;
enum i32 IDNO = 7;

fn MessageBoxA(hWnd: HWND, lpText: LPCSTR, lpCaptions: LPCSTR, uType: UINT) i32;
fn MessageBoxW(hWnd: HWND, lpText: LPWSTR, lpCaptions: LPWSTR, uType: UINT) i32;

fn ReleaseDC(hWnd: HWND, hDC: HDC) i32;

fn DestroyWindow(hWnd: HWND) BOOL;

fn UnregisterClassA(lpClassName: LPCSTR, hInstance: HINSTANCE) BOOL;
fn UnregisterClassW(lpClassName: LPWSTR, hInstance: HINSTANCE) BOOL;

alias WNDPROC = fn!Windows(HWND, UINT, WPARAM, LPARAM) LRESULT;

enum UINT CS_BYTEALIGNCLIENT = 0x00001000;
enum UINT CS_BYTEALIGNWINDOW = 0x00002000;
enum UINT CS_CLASSDC         = 0x00000040;
enum UINT CS_DBLCLK          = 0x00000008;
enum UINT CS_DROPSHADOW      = 0x00020000;
enum UINT CS_GLOBALCLASS     = 0x00004000;
enum UINT CS_HREDRAW         = 0x00000002;
enum UINT CS_NOCLOSE         = 0x00000200;
enum UINT CS_OWNDC           = 0x00000020;
enum UINT CS_PARENTDC        = 0x00000080;
enum UINT CS_SAVEBITS        = 0x00000800;
enum UINT CS_VREDRAW         = 0x00000001;

enum UINT WS_OVERLAPPED   = 0x00000000L;
enum UINT WS_CAPTION      = 0x00C00000L;
enum UINT WS_SYSMENU      = 0x00080000L;
enum UINT WS_THICKFRAME   = 0x00040000L;
enum UINT WS_MINIMIZEBOX  = 0x00020000L;
enum UINT WS_MAXIMIZEBOX  = 0x00010000L;
enum UINT WS_OVERLAPPEDWINDOW = 0x00CF0000;
enum UINT WS_POPUP        = 0x80000000L;
enum UINT WS_CLIPCHILDREN = 0x02000000L;
enum UINT WS_CLIPSIBLINGS = 0x04000000L;

enum UINT WS_EX_APPWINDOW = 0x00040000L;
enum UINT WS_EX_WINDOWEDGE = 0x00000100L;

struct WNDCLASSA
{
	style: UINT;
	lpfnWndProc: WNDPROC;
	cbClsExtra: i32;
	cbWndExtra: i32;
	hInstance: HINSTANCE;
	hIcon: HICON;
	hCursor: HCURSOR;
	hbrBackground: HBRUSH;
	lpszMenuName: LPCSTR;
	lpszClassName: LPCSTR;
}
alias PWNDCLASSA = WNDCLASSA*;

struct WNDCLASSW
{
	style: UINT;
	lpfnWndProc: WNDPROC;
	cbClsExtra: i32;
	cbWndExtra: i32;
	hInstance: HINSTANCE;
	hIcon: HICON;
	hCursor: HCURSOR;
	hbrBackground: HBRUSH;
	lpszMenuName: LPWSTR;
	lpszClassName: LPWSTR;
}
alias PWNDCLASSW = WNDCLASSW*;

struct RECT
{
	left: LONG;
	top: LONG;
	right: LONG;
	bottom: LONG;
}
alias PRECT = RECT*;

fn GetModuleHandleA(lpModuleName: LPCSTR) HMODULE;
fn GetModuleHandleW(lpModuleName: LPWSTR) HMODULE;
fn GetModuleFileNameA(HMODULE, const(char)*, DWORD) DWORD;

// C Win32 has a macro that casts to LPCSTR/LPWSTR as appropriate. We'll leave that to the user.
enum IDI_WINLOGO = 32517;

fn LoadIconA(hInstance: HINSTANCE, lpIconName: LPCSTR) HICON;
fn LoadIconW(hInstance: HINSTANCE, lpIconName: LPWSTR) HICON;

// C Win32 has a macro that casts to LPCSTR/LPWSTR as appropriate. We'll leave that to the user. 
enum IDC_ARROW = 32512;

fn LoadCursorA(hInstance: HINSTANCE, lpCursorName: LPCSTR) HCURSOR;
fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: LPWSTR) HCURSOR;

fn RegisterClassA(lpWndClass: WNDCLASSA*) ATOM;
fn RegisterClassW(lpWndClass: WNDCLASSW*) ATOM;

fn AdjustWindowRectEx(lpRect: RECT*, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) BOOL;

fn CreateWindowExA(DWORD, LPCSTR, LPCSTR, DWORD, i32, i32, i32, i32, HWND, HMENU, HINSTANCE, LPVOID) HWND;
fn CreateWindowExW(DWORD, LPWSTR, LPWSTR, DWORD, i32, i32, i32, i32, HWND, HMENU, HINSTANCE, LPVOID) HWND;

enum DWORD PFD_DRAW_TO_WINDOW = 0x00000004L;
enum DWORD PFD_SUPPORT_OPENGL = 0x00000020L;
enum DWORD PFD_DOUBLEBUFFER   = 0x00000001L;
enum BYTE PFD_TYPE_RGBA = 0;
enum DWORD PFD_MAIN_PLANE = 0;

struct PIXELFORMATDESCRIPTOR
{
	nSize: WORD;
	nVersion: WORD;
	dwFlags: DWORD;
	iPixelType: BYTE;
	cColorBits: BYTE;
	cRedBits: BYTE;
	cRedShift: BYTE;
	cGreenBits: BYTE;
	cGreenShift: BYTE;
	cBlueBits: BYTE;
	cBlueShift: BYTE;
	cAlphaBits: BYTE;
	cAlphaShift: BYTE;
	cAccumBits: BYTE;
	cAccumRedBits: BYTE;
	cAccumGreenBits: BYTE;
	cAccumBlueBits: BYTE;
	cAccumAlphaBits: BYTE;
	cDepthBits: BYTE;
	cStencilBits: BYTE;
	cAuxBuffers: BYTE;
	iLayerType: BYTE;
	bReserved: BYTE;
	dwLayerMask: DWORD;
	dwVisibleMask: DWORD;
	dwDamageMask: DWORD;
}
alias PPIXELFORMATDESCRIPTOR = PIXELFORMATDESCRIPTOR*;

fn GetDC(hWnd: HWND) HDC;

fn ChoosePixelFormat(hdc: HDC, ppfd: PIXELFORMATDESCRIPTOR*) i32;

fn SetPixelFormat(hdc: HDC, iPixelFormat: i32, ppfd: PIXELFORMATDESCRIPTOR*) BOOL;

enum SW_SHOW = 5;

fn ShowWindow(hWnd: HWND, nCmdShow: i32) BOOL;

fn SetForegroundWindow(hWnd: HWND) BOOL;

fn SetFocus(hWnd: HWND) HWND;

enum UNICODE_NOCHAR = 0xFFFF;
enum WM_ACTIVATE = 0x0006;
enum WM_SYSCOMMAND = 0x0112;
enum WM_CLOSE = 0x0010;
enum WM_KEYDOWN = 0x0100;
enum WM_KEYUP = 0x0101;
enum WM_SIZE = 0x0005;
enum WM_QUIT = 0x0012;
enum WM_MOUSEMOVE = 0x0200;
enum WM_SYSKEYDOWN = 0x0104;
enum WM_SYSKEYUP = 0x0105;
enum WM_CHAR = 0x0102;
enum WM_UNICHAR = 0x0109;
enum WM_LBUTTONDOWN = 0x0201;
enum WM_LBUTTONUP = 0x0202;
enum WM_MBUTTONDOWN = 0x0207;
enum WM_MBUTTONUP = 0x0208;
enum WM_RBUTTONDOWN = 0x0204;
enum WM_RBUTTONUP = 0x0205;
enum WM_XBUTTONDOWN = 0x020B;
enum WM_XBUTTONUP = 0x020C;
enum WM_PAINT = 0x0F;
enum WM_ERASEBKGND = 0x0014;

enum SC_SCREENSAVE = 0xF140;
enum SC_MONITORPOWER = 0xF170;

enum SM_CXSCREEN = 0;
enum SM_CYSCREEN = 1;
enum VK_CLEAR = 0x0C;
enum VK_MODECHANGE = 0x1F;
enum VK_SELECT = 0x29;
enum VK_EXECUTE = 0x2B;
enum VK_HELP = 0x2F;
enum VK_PAUSE = 0x13;
enum VK_NUMLOCK = 0x90;
enum VK_F13 = 0x7C;
enum VK_F14 = 0x7D;
enum VK_F15 = 0x7E;
enum VK_F16 = 0x7F;
enum VK_F17 = 0x80;
enum VK_F18 = 0x81;
enum VK_F19 = 0x82;
enum VK_F20 = 0x83;
enum VK_F21 = 0x84;
enum VK_F22 = 0x85;
enum VK_F23 = 0x86;
enum VK_F24 = 0x87;
enum VK_OEM_NEC_EQUAL = 0x92;
enum VK_BROWSER_BACK = 0xA6;
enum VK_BROWSER_FORWARD = 0xA7;
enum VK_BROWSER_REFRESH = 0xA8;
enum VK_BROWSER_STOP = 0xA9;
enum VK_BROWSER_SEARCH = 0xAA;
enum VK_BROWSER_FAVORITES = 0xAB;
enum VK_BROWSER_HOME = 0xAC;
enum VK_VOLUME_MUTE = 0xAD;
enum VK_VOLUME_DOWN = 0xAE;
enum VK_VOLUME_UP = 0xAF;
enum VK_MEDIA_NEXT_TRACK = 0xB0;
enum VK_MEDIA_PREV_TRACK = 0xB1;
enum VK_MEDIA_STOP = 0xB2;
enum VK_MEDIA_PLAY_PAUSE = 0xB3;
enum VK_LAUNCH_MAIL = 0xB4;
enum VK_LAUNCH_MEDIA_SELECT = 0xB5;
enum VK_OEM_102 = 0xE2;
enum VK_ATTN = 0xF6;
enum VK_CRSEL = 0xF7;
enum VK_EXSEL = 0xF8;
enum VK_OEM_CLEAR = 0xFE;
enum VK_LAUNCH_APP1 = 0xB6;
enum VK_LAUNCH_APP2 = 0xB7;

fn PostQuitMessage(nExitCode: i32);

fn DefWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT;

struct MSG
{
	hwnd: HWND;
	message: UINT;
	wParam: WPARAM;
	lParam: LPARAM;
	time: DWORD;
	pt: POINT;
}
alias PMSG = MSG*;
alias LPMSG = MSG*;

enum UINT PM_NOREMOVE = 0x0000;
enum UINT PM_REMOVE = 0x0001;
enum UINT PM_NOYIELD = 0x0002;

fn PeekMessageA(lpMsg: LPMSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) BOOL;
fn PeekMessageW(lpMsg: LPMSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) BOOL;

fn TranslateMessage(lpMsg: MSG*) BOOL;
fn DispatchMessageA(lpMsg: MSG*) LRESULT;
fn DispatchMessageW(lpMsg: MSG*) LRESULT;

fn SwapBuffers(HDC) BOOL;

struct COORD
{
	x: SHORT;
	y: SHORT;
}
alias PCOORD = COORD*;

fn SetConsoleCursorPosition(hConsoleOutput: HANDLE, dwCursorPosition: COORD) BOOL;
fn WriteConsoleA(HANDLE, const(void)*, DWORD, LPDWORD, LPVOID) BOOL;
fn WriteConsoleW(HANDLE, const(void)*, DWORD, LPDWORD, LPVOID) BOOL;
fn SetConsoleTitleA(LPCSTR) BOOL;
fn SetConsoleTitleW(LPWSTR) BOOL;
fn ReadConsoleA(HANDLE, LPVOID, DWORD, LPDWORD, LPVOID) BOOL;
fn ReadConsoleW(HANDLE, LPVOID, DWORD, LPDWORD, LPVOID) BOOL;

fn FreeLibrary(lib: HMODULE) void*;
fn GetProcAddress(HMODULE, LPCSTR) void*;
fn LoadLibraryA(LPCSTR) HMODULE;
fn GetTickCount() DWORD;
fn SetCapture(HWND);
fn ReleaseCapture();
fn GetWindowLongPtrA(HWND, i32) LONG_PTR;
enum GWL_STYLE = -16;
fn SetWindowLongPtrA(HWND, i32, LONG_PTR) LONG_PTR;
enum WS_MINIMIZE = 0x20000000L;
enum WS_MAXIMIZE = 0x01000000L;
enum WS_VISIBLE  = 0x10000000L;
fn InvalidateRect(HWND, RECT*, BOOL) BOOL;
fn UpdateWindow(HWND) BOOL;
fn SetWindowPos(HWND, HWND, i32, i32, i32, i32, UINT) BOOL;
enum SWP_NOMOVE = 0x0002;
enum SWP_FRAMECHANGED = 0x0020;

fn ChangeDisplaySettingsExA(LPCSTR, DEVMODE*, HWND, DWORD, LPVOID) LONG;
alias HMONITOR = HANDLE;
fn MonitorFromWindow(HWND, DWORD) HMONITOR;
enum MONITOR_DEFAULTTOPRIMARY = 1;
struct MONITORINFOEX
{
	cbSize: DWORD;
	rcMonitor: RECT;
	rcWork: RECT;
	dwFlags: DWORD;
	szDevice: TCHAR[32];
}
fn GetMonitorInfoA(HMONITOR, MONITORINFOEX*) BOOL;

fn GetSystemMetrics(i32) i32;

fn QueryPerformanceFrequency(LARGE_INTEGER*) BOOL;
fn QueryPerformanceCounter(LARGE_INTEGER*) BOOL;

fn VirtualAlloc(LPVOID, SIZE_T, DWORD, DWORD) LPVOID;
fn VirtualFree(LPVOID, SIZE_T, DWORD) BOOL;

enum DWORD MEM_COMMIT = 0x00001000;
enum DWORD MEM_RESERVE = 0x00002000;
enum DWORD MEM_DECOMMIT = 0x00004000;
enum DWORD PAGE_EXECUTE_READWRITE = 0x40;
enum DWORD MEM_RELEASE = 0x8000;

fn CreateMutexA(LPSECURITY_ATTRIBUTES, BOOL, LPCSTR) HANDLE;
fn CreateMutexW(LPSECURITY_ATTRIBUTES, BOOL, LPCWSTR) HANDLE;
fn ReleaseMutex(HANDLE) BOOL;

fn LocalFree(HLOCAL) HLOCAL;

// Registry Stuff

enum HKEY_CLASSES_ROOT        = 0x80000000;
enum HKEY_CURRENT_USER        = 0x80000001;
enum HKEY_LOCAL_MACHINE       = 0x80000002;
enum HKEY_USERS               = 0x80000003;
enum HKEY_CURRENT_CONFIG      = 0x80000005;
enum HKEY_PERFORMANCE_DATA    = 0x80000004;
enum HKEY_PERFORMANCE_TEXT    = 0x80000050;
enum HKEY_PERFORMANCE_NLSTEXT = 0x80000060;

alias REGSAM = ULONG;
enum REGSAM KEY_QUERY_VALUE        = 0x00000001;
enum REGSAM KEY_SET_VALUE          = 0x00000002;
enum REGSAM KEY_CREATE_SUB_KEY     = 0x00000004;
enum REGSAM KEY_ENUMERATE_SUB_KEYS = 0x00000008;
enum REGSAM KEY_NOTIFY             = 0x00000010;
enum REGSAM KEY_CREATE_LINK        = 0x00000020;
enum REGSAM KEY_WOW64_64KEY        = 0x00000100;
enum REGSAM KEY_WOW64_32KEY        = 0x00000200;
enum REGSAM KEY_WRITE              = 0x00020006;
enum REGSAM KEY_READ               = 0x00020019;
enum REGSAM KEY_EXECUTE            = 0x00020019;
enum REGSAM KEY_ALL_ACCESS         = 0x000F003F;

enum DWORD REG_OPTION_BACKUP_RESTORE = 0x00000004L;
enum DWORD REG_OPTION_CREATE_LINK    = 0x00000002L;
enum DWORD REG_OPTION_NON_VOLATILE   = 0x00000000L;
enum DWORD REG_OPTION_VOLATILE       = 0x00000001L;

enum DWORD REG_CREATED_NEW_KEY     = 0x00000001L;
enum DWORD REG_OPENED_EXISTING_KEY = 0x00000002L;

enum DWORD REG_OPTION_OPEN_LINK = 0x00000008L;

enum DWORD REG_NONE = 0;
enum DWORD REG_SZ   = 1;

fn RegCloseKey(HKEY) LONG;
fn RegConnectRegistryA(LPCSTR, HKEY, PHKEY) LONG;
fn RegConnectRegistryW(LPCWSTR, HKEY, PHKEY) LONG;
fn RegCopyTreeA(HKEY, LPCSTR, HKEY) LONG;
fn RegCopyTreeW(HKEY, LPCWSTR, HKEY) LONG;
fn RegCreateKeyExA(HKEY, LPCSTR, DWORD, LPSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD) LONG;
fn RegCreateKeyExW(HKEY, LPCWSTR, DWORD, LPWSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD) LONG;
fn RegCreateKeyTransactedA(HKEY, LPCSTR, DWORD, LPSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD, HANDLE, PVOID) LONG;
fn RegCreateKeyTransactedW(HKEY, LPCWSTR, DWORD, LPWSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD, HANDLE, PVOID) LONG;
fn RegOpenKeyExA(HKEY, LPCSTR, DWORD, REGSAM, PHKEY) LONG;
fn RegOpenKeyExW(HKEY, LPCWSTR, DWORD, REGSAM, PHKEY) LONG;
fn RegQueryValueExA(HKEY, LPCSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD) LONG;
fn RegQueryValueExW(HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD) LONG;
fn RegEnumKeyExA(HKEY, DWORD, LPCSTR, LPDWORD, LPDWORD, LPSTR, LPDWORD, PFILETIME) LONG;
fn RegEnumKeyExW(HKEY, DWORD, LPCWSTR, LPDWORD, LPDWORD, LPWSTR, LPDWORD, PFILETIME) LONG;
fn RegQueryInfoKeyA(HKEY, LPCSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, PFILETIME) LONG;
fn RegQueryInfoKeyW(HKEY, LPCWSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, PFILETIME) LONG;

fn CreateEventA(LPSECURITY_ATTRIBUTES, BOOL, BOOL, LPCSTR) HANDLE;
fn CreateEventW(LPSECURITY_ATTRIBUTES, BOOL, BOOL, LPCWSTR) HANDLE;
fn SetEvent(HANDLE) BOOL;
alias LPTHREAD_START_ROUTINE = fn(LPVOID) DWORD;
fn CreateThread(LPSECURITY_ATTRIBUTES, SIZE_T, LPTHREAD_START_ROUTINE, LPVOID, DWORD, LPDWORD) HANDLE;

fn FlushFileBuffers(HANDLE) BOOL;

fn RaiseException(DWORD, DWORD, DWORD, ULONG_PTR*);
fn RtlRaiseException(PEXCEPTION_RECORD);
fn RtlUnwindEx(PVOID, PVOID, PEXCEPTION_RECORD, PVOID, PCONTEXT, PUNWIND_HISTORY_TABLE);
fn RtlLookupFunctionEntry(ControlPc: DWORD64, ImageBase: PDWORD64,
	HistoryTable: PUNWIND_HISTORY_TABLE) PRUNTIME_FUNCTION;

enum EXCEPTION_EXECUTE_HANDLER = 1;
enum EXCEPTION_CONTINUE_SEARCH = 0;
enum EXCEPTION_CONTINUE_EXECUTION = -1;

enum EH_NONCONTINUABLE   = 0x01U;
enum EH_UNWINDING        = 0x02U;
enum EH_EXIT_UNWIND      = 0x04U;
enum EH_STACK_INVALID    = 0x08U;
enum EH_NESTED_CALL      = 0x10U;
enum EH_TARGET_UNWIND    = 0x20U;
enum EH_COLLIDED_UNWIND  = 0x40U;
enum EH_UNWIND           = 0x66U;

enum EXCEPTION_CONTINUABLE        = 0;
enum EXCEPTION_NONCONTINUABLE     = EH_NONCONTINUABLE;
enum STATUS_UNWIND_CONSOLIDATE = 0x80000029;

enum EXCEPTION_DISPOSITION
{
	ExceptionContinueExecution,
	ExceptionContinueSearch,
	ExceptionNestedException,
	ExceptionCollidedUnwind
}

enum EXCEPTION_MAXIMUM_PARAMETERS = 15;

struct EXCEPTION_RECORD
{
	ExceptionCode: DWORD;
	ExceptionFlags: DWORD;
	ExceptionRecord: EXCEPTION_RECORD*;
	ExceptionAddress: PVOID;
	NumberParameters: DWORD;
	ExceptionInformation: ULONG_PTR[EXCEPTION_MAXIMUM_PARAMETERS];
}
alias PEXCEPTION_RECORD = EXCEPTION_RECORD*;

alias EXCEPTION_ROUTINE = fn(PEXCEPTION_RECORD, PVOID, PCONTEXT, PVOID)
	EXCEPTION_DISPOSITION;
alias PEXCEPTION_ROUTINE = EXCEPTION_ROUTINE;

version (X86_64) {
	struct XSAVE_FORMAT
	{
		ControlWorld: WORD;
		StatusWord: WORD;
		TagWord: BYTE;
		Reserved1: BYTE;
		ErrorOpcode: WORD;
		ErrorOffset: DWORD;
		ErrorSelector: WORD;
		Reserved2: WORD;
		DataOffset: DWORD;
		DataSelector: WORD;
		Reserved3: WORD;
		MxCsr: DWORD;
		MxCsr_Mask: DWORD;
		FloatRegisters: M128A[8];
		XmmRegisters: M128A[16];
		Reserved4: BYTE[96];
	}
	alias PXSAVE_FORMAT = XSAVE_FORMAT*;
	alias XMM_SAVE_AREA32 = XSAVE_FORMAT;

	struct NEON128
	{
		Low: ULONGLONG;
		High: LONGLONG;
	}

	struct CONTEXT
	{
		P1Home: DWORD64;
		P2Home: DWORD64;
		P3Home: DWORD64;
		P4Home: DWORD64;
		P5Home: DWORD64;
		P6Home: DWORD64;

		ContextFlags: DWORD;
		MxCsr: DWORD;

		SegCs: WORD;
		SegDs: WORD;
		SegEs: WORD;
		SegFs: WORD;
		SegGs: WORD;
		SegSs: WORD;
		EFlags: DWORD;

		Dr0: DWORD64;
		Dr1: DWORD64;
		Dr2: DWORD64;
		Dr3: DWORD64;
		Dr6: DWORD64;
		Dr7: DWORD64;

		Rax: DWORD64;
		Rcx: DWORD64;
		Rdx: DWORD64;
		Rbx: DWORD64;
		Rsp: DWORD64;
		Rbp: DWORD64;
		Rsi: DWORD64;
		Rdi: DWORD64;
		 R8: DWORD64;
		 R9: DWORD64;
		R10: DWORD64;
		R11: DWORD64;
		R12: DWORD64;
		R13: DWORD64;
		R14: DWORD64;
		R15: DWORD64;

		Rip: DWORD64;

		struct __FPREGS {
			Header: M128A[2];
			Legacy: M128A[8];
			Xmm0: M128A;
			Xmm1: M128A;
			Xmm2: M128A;
			Xmm3: M128A;
			Xmm4: M128A;
			Xmm5: M128A;
			Xmm6: M128A;
			Xmm7: M128A;
			Xmm8: M128A;
			Xmm9: M128A;
			Xmm10: M128A;
			Xmm11: M128A;
			Xmm12: M128A;
			Xmm13: M128A;
			Xmm14: M128A;
			Xmm15: M128A;
		}

		union _u {
			FltSave: XMM_SAVE_AREA32;
			Q: NEON128[16];
			D: ULONGLONG[32];
			s: __FPREGS;
			S: DWORD[32];
		}
		u: _u;

		VectorRegister: M128A[26];
		VectorControl: DWORD64;

		DebugControl: DWORD64;
		LastBranchToRip: DWORD64;
		LastBranchFromRip: DWORD64;
		LastExceptionToRip: DWORD64;
		LastExceptionFromRip: DWORD64;
	}
	alias PCONTEXT = CONTEXT*;

	struct RUNTIME_FUNCTION
	{
		BeginAddress: DWORD;
		EndAddress: DWORD;
		UnwindInfoAddress: DWORD;
	}
	alias PRUNTIME_FUNCTION = RUNTIME_FUNCTION*;

	enum UNWIND_HISTORY_TABLE_SIZE = 12;

	struct UNWIND_HISTORY_TABLE_ENTRY
	{
		ImageBase: DWORD64;
		FunctionEntry: PRUNTIME_FUNCTION;
	}
	alias PUNWIND_HISTORY_TABLE_ENTRY = UNWIND_HISTORY_TABLE_ENTRY*;

	struct UNWIND_HISTORY_TABLE
	{
		Count: DWORD;
		LocalHint: BYTE;
		GlobalHint: BYTE;
		Search: BYTE;
		Once: BYTE;
		LowAddress: DWORD64;
		HighAddress: DWORD64;
		Entry: UNWIND_HISTORY_TABLE_ENTRY[UNWIND_HISTORY_TABLE_SIZE];
	}
	alias PUNWIND_HISTORY_TABLE = UNWIND_HISTORY_TABLE*;

	struct DISPATCHER_CONTEXT
	{
		ControlPc: DWORD64;
		ImageBase: DWORD64;
		FunctionEntry: PRUNTIME_FUNCTION;
		EstablisherFrame: DWORD64;
		TargetIp: DWORD64;
		ContextRecord: PCONTEXT;
		LanguageHandler: PEXCEPTION_ROUTINE;
		HandlerData: PVOID;
		HistoryTable: PUNWIND_HISTORY_TABLE;
		ScopeIndex: DWORD;
		Fill0: DWORD;
	}
	alias PDISPATCHER_CONTEXT = DISPATCHER_CONTEXT*;
}

// Helper functions needs to be marked with extern volt so
// they do not collide with other C function with similar names.
// DO NOT ADD ANY WINDOWS FUNCTIONS AFTER THIS POINT!
extern(Volt):

fn LOWORD(dw: DWORD) WORD
{
	return cast(WORD)dw;
}

fn HIWORD(dw: DWORD) WORD
{
	return cast(WORD)((dw >> 16) & 0xFFFF);
}

fn GET_X_LPARAM(l: LPARAM) i32
{
	return cast(i32)cast(i16)LOWORD(cast(DWORD)l);
}

fn GET_Y_LPARAM(l: LPARAM) i32
{
	return cast(i32)cast(i16)HIWORD(cast(DWORD)l);
}

fn GET_XBUTTON_WPARAM(w: WPARAM) i32
{
	return cast(i32)cast(i16)HIWORD(cast(DWORD)w);
}
// DO NOT ADD ANY WINDOWS FUNCTIONS AFTER THIS!
