/*#D*/
// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * DWARF enums and code.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.dwarf;


/*
 *
 * Dwarf enums.
 *
 */

enum DwAte
{
	Address      = 0x01,
	Boolean      = 0x02,
	ComplexFloat = 0x03,
	Float        = 0x04,
	Signed       = 0x05,
	SignedChar   = 0x06,
	Unsigned     = 0x07,
	UnsignedChar = 0x08,
	LoUser       = 0x80,
	HiUser       = 0x81,
}
