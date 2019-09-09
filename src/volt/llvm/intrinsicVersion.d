/*#D*/
// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Get the intrinsic version.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.intrinsicVersion;


enum V1 = 1;
enum V2 = 2;

int get()
{
	version (LLVMVersion7AndAbove) {
		return V2;
	} else version (LlvmVersion7) {
		return V2;
	} else {
		return V1;
	}
}
