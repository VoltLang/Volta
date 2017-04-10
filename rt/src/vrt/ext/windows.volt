// Copyright © 2016-2017, Bernard Helyer.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
module vrt.ext.windows;

version (Windows):

alias BYTE = u8;
alias WORD = u16;
alias DWORD = u32;
alias HMODULE = void*;
alias PVOID = void*;
alias LPVOID = void*;
alias SIZE_T = size_t;
alias DWORD_PTR = size_t;
alias BOOL = i32;

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

extern (Windows) fn GetSystemInfo(SYSTEM_INFO*);

extern (Windows) fn VirtualAlloc(LPVOID, SIZE_T, DWORD, DWORD) LPVOID;
enum DWORD MEM_COMMIT = 0x00001000;
enum DWORD MEM_RESERVE = 0x00002000;
enum DWORD PAGE_EXECUTE_READWRITE = 0x40;
extern (Windows) fn VirtualFree(LPVOID, SIZE_T, DWORD) BOOL;
enum DWORD MEM_RELEASE = 0x8000;