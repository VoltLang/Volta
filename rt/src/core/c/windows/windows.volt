// Copyright © 2013-2017, Bernard Helyer.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
module core.c.windows.windows;

version (!Metal):
version (Windows):

// As it stands, this module only has the bits of WIN32 that have been used.
// Pull requests to add more welcome.

import core.c.stdarg;


extern (Windows):

alias UINT = u32;
alias WORD = u16;
alias DWORD = u32;
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
alias TCHAR = char;
alias LONG = i32;
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
enum FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;

fn FormatMessageA(DWORD, LPCVOID, DWORD, DWORD, LPCSTR, DWORD, va_list*) DWORD;
fn FormatMessageW(DWORD, LPCVOID, DWORD, DWORD, LPCWSTR, DWORD, va_list*) DWORD;

fn CreateProcessA(LPCSTR, LPSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCSTR, LPSTARTUPINFOA, LPPROCESS_INFORMATION) BOOL;
fn CreateProcessW(LPCWSTR, LPWSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCWSTR, LPSTARTUPINFOW, LPPROCESS_INFORMATION) BOOL;

enum WAIT_OBJECT_0 = 0L;
@property fn INFINITE() DWORD { return cast(DWORD) 0xFFFFFFFF; }

fn WaitForSingleObject(HANDLE, DWORD) DWORD;
fn WaitForMultipleObjects(DWORD, HANDLE*, BOOL, DWORD) DWORD;
fn CloseHandle(HANDLE) BOOL;
fn GetExitCodeProcess(HANDLE, LPDWORD) BOOL;

enum HANDLE_FLAG_INHERIT = 0x00000001;
enum HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x00000002;

fn GetHandleInformation(HANDLE, LPDWORD) BOOL;
fn SetHandleInformation(HANDLE, DWORD, DWORD) BOOL;

@property fn STD_INPUT_HANDLE() DWORD { return cast(DWORD) -10; }
@property fn STD_OUTPUT_HANDLE() DWORD { return cast(DWORD) -11; }
@property fn STD_ERROR_HANDLE() DWORD { return cast(DWORD) -12; }

fn GetStdHandle(DWORD) HANDLE;

fn CreatePipe(PHANDLE, PHANDLE, LPSECURITY_ATTRIBUTES, DWORD) BOOL;

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

fn ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED) BOOL;

struct SYSTEM_INFO
{
	wReserved: DWORD;
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

fn Sleep(DWORD);

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

enum ERROR_FILE_NOT_FOUND = 2;
enum ERROR_NO_MORE_FILES = 18;

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

fn LOWORD(dw: DWORD) WORD
{
	return cast(WORD)dw;
}

fn HIWORD(dw: DWORD) WORD
{
	return cast(WORD)((dw >> 16) & 0xFFFF);
}

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

fn GetSystemMetrics(i32) i32;