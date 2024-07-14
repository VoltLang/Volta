/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Comdat;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
version(LLVMVersion13AndAbove) {
	enum LLVMComdatSelectionKind {
		AnyComdat = 0,
		ExactMatchComdat = 1,
		LargestComdat = 2,
		NoDeduplicateComdat = 3,
		SameSizeComdat = 4,
	}
} else {
	enum LLVMComdatSelectionKind {
		AnyComdat = 0,
		ExactMatchComdat = 1,
		LargestComdat = 2,
		NoDuplicatesComdat = 3,
		SameSizeComdat = 4,
	}
}
LLVMComdatRef LLVMGetComdat(LLVMValueRef V);
LLVMComdatSelectionKind LLVMGetComdatSelectionKind(LLVMComdatRef C);
LLVMComdatRef LLVMGetOrInsertComdat(LLVMModuleRef M, const(char)* Name);
void LLVMSetComdat(LLVMValueRef V, LLVMComdatRef C);
void LLVMSetComdatSelectionKind(LLVMComdatRef C, LLVMComdatSelectionKind Kind);
