/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.ErrorHandling;

public import lib.llvm.c.Types;


alias LLVMFatalErrorHandler = extern(C) void function(const char *Reason);


extern(C):

//#--- Auto generated below ---#
void LLVMEnablePrettyStackTrace();
void LLVMInstallFatalErrorHandler(LLVMFatalErrorHandler Handler);
void LLVMResetFatalErrorHandler();
