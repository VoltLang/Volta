// Copyright © 2016-2017, Bernard Helyer.
// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.sections.windows;

version (Windows):

import vrt.gc.util;


global sections: const(void*)[][];

fn initSections()
{
	addSection(findImageSection(".bss"));
	addSection(findImageSection(".data"));
}


private:

/// Global store for sections.
global privStore: const(void*)[][512];
/// Global count of sections.
global privCount: size_t;

// Adds a section to the private store and updates the sections global.
fn addSection(section: void[])
{
	if (section.length == 0) {
		return;
	}

	privStore[privCount++] = makeRange(section);
	sections = privStore[0 .. privCount];
}

alias BYTE = u8;
alias WORD = u16;
alias DWORD = u32;
alias HMODULE = void*;
alias PVOID = void*;

enum IMAGE_DOS_SIGNATURE = 0x5A4D; // MZ
struct IMAGE_DOS_HEADER
{
	e_magic: u16;
	e_res2: u16[29];
	e_lfanew: i32;
}

struct IMAGE_FILE_HEADER
{
	Machine: WORD;
	NumberOfSections: WORD;
	TimeDateStamp: DWORD;
	PointerToSymbolTable: DWORD;
	NumberOfSymbols: DWORD;
	SizeOfOptionalHeader: WORD;
	Characteristics: WORD;
}

struct IMAGE_DATA_DIRECTORY
{
	VirtualAddress: DWORD;
	Size: DWORD;
}

struct IMAGE_NT_HEADERS
{
	Signature: DWORD;
	FileHeader: IMAGE_FILE_HEADER;
}

struct IMAGE_SECTION_HEADER
{
	Name: BYTE[8/*IMAGE_SIZEOF_SHORT_NAME*/];
	union _misc
	{
		PhysicalAddress: DWORD;
		VirtualSize: DWORD;
	}
	Misc: _misc;
	VirtualAddress: DWORD;
	SizeOfRawData: DWORD;
	PointerToRawData: DWORD;
	PointerToRelocations: DWORD;
	PointerToLinenumbers: DWORD;
	NumberOfRelocations: WORD;
	NumberOfLinenumbers: WORD;
	Characteristics: DWORD;
}

/* Symbols created by the compiler/linker and inserted into the
 * object file that 'bracket' sections.
 */
extern(C) extern global __ImageBase: void*;

fn compareSectionName(ref section: IMAGE_SECTION_HEADER, name: string) bool
{
	if (name[] != cast(string)section.Name[0 .. name.length]) {
		return false;
	}
	return name.length == 8 || section.Name[name.length] == 0;
}

fn findImageSection(name: string) void[]
{
	// section name from string table not supported
	if (name.length > 8) {
		return null;
	}

	doshdr := cast(IMAGE_DOS_HEADER*) &__ImageBase;
	if (doshdr.e_magic != IMAGE_DOS_SIGNATURE) {
		return null;
	}

	nthdr := cast(IMAGE_NT_HEADERS*)(cast(void*)doshdr + doshdr.e_lfanew);
	hSize := typeid(IMAGE_NT_HEADERS).size +
		nthdr.FileHeader.SizeOfOptionalHeader;
	sections := cast(IMAGE_SECTION_HEADER*)(cast(void*)nthdr + hSize);

	foreach (i; 0 .. nthdr.FileHeader.NumberOfSections) {
		if (compareSectionName(ref sections[i], name)) {
			base := cast(void*)&__ImageBase;
			addr := base + sections[i].VirtualAddress;
			return addr[0 .. sections[i].Misc.VirtualSize];
		}
	}

	return null;
}
