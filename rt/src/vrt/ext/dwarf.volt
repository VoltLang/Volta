// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.ext.dwarf;


extern(C) void exit(int);

// True for now
alias uintptr_t = size_t;

struct DW_Context
{
	void* textrel;
	void* datarel;
	void* funcrel;
}

enum {
	DW_EH_PE_omit    = 0xff, // value is not present

	// value format
	DW_EH_PE_absptr  = 0x00,
	DW_EH_PE_uleb128 = 0x01,
	DW_EH_PE_udata2  = 0x02, // unsigned 2-byte
	DW_EH_PE_udata4  = 0x03,
	DW_EH_PE_udata8  = 0x04,
	DW_EH_PE_sleb128 = 0x09,
	DW_EH_PE_sdata2  = 0x0a,
	DW_EH_PE_sdata4  = 0x0b,
	DW_EH_PE_sdata8  = 0x0c,

	// value meaning
	DW_EH_PE_pcrel    = 0x10, // relative to program counter
	DW_EH_PE_textrel  = 0x20, // relative to .text
	DW_EH_PE_datarel  = 0x30, // relative to .got or .eh_frame_hdr
	DW_EH_PE_funcrel  = 0x40, // relative to beginning of function
	DW_EH_PE_aligned  = 0x50, // is an aligned void*

	// value is a pointer to the actual value
	// this is a mask on top of one of the above
	DW_EH_PE_indirect = 0x80
}

uintptr_t dw_read_uleb128(const(ubyte)** data)
{
	uintptr_t result;
	uintptr_t shift;
	ubyte b;
	auto p = *data;

	do {
		b = *p++;
		result |= cast(uintptr_t)(b & 0x7f) << shift;
		shift += 7;
	} while (b & 0x80);

	*data = p;

	return result;
}

static uintptr_t dw_read_sleb128(const(ubyte)** data)
{
	uintptr_t result;
	uintptr_t shift;
	ubyte b;
	auto p = *data;

	do {
		b = *p++;
		result |= cast(uintptr_t)(b & 0x7f) << shift;
		shift += 7;
	} while (b & 0x80);

	*data = p;

	if ((b & 0x40) != 0 && (shift < typeid(uintptr_t).size * 8)) {
		result |= (cast(uintptr_t)-1 << shift);
	}

	return result;
}

ubyte dw_read_ubyte(const(ubyte)** data)
{
	auto p = *data;
	auto result = cast(ubyte)*p++;
	*data = p;
	return result;
}

size_t dw_encoded_size(ubyte encoding)
{
	switch (encoding & 0x0F) {
	case DW_EH_PE_absptr:
		return typeid(void*).size;
	case DW_EH_PE_udata2:
		return typeid(ushort).size;
	case DW_EH_PE_udata4:
		return typeid(uint).size;
	case DW_EH_PE_udata8:
		return typeid(ulong).size;
	case DW_EH_PE_sdata2:
		return typeid(short).size;
	case DW_EH_PE_sdata4:
		return typeid(int).size;
	case DW_EH_PE_sdata8:
		return typeid(long).size;
	default:
		object.vrt_printf("%s: unhandled case\n", __FUNCTION__);
		exit(-1);
		break;
	}
	assert(false); // To please cfg detection
}

uintptr_t dw_read_encoded(const(ubyte)** data, ubyte encoding)
{
	uintptr_t result;
	auto pc = *data;
	auto p = *data;

	switch (encoding & 0x0F) {
	case DW_EH_PE_uleb128:
		result = dw_read_uleb128(&p);
		break;
	case DW_EH_PE_sleb128:
		result = dw_read_sleb128(&p);
		break;
	case DW_EH_PE_absptr:
		result = *(cast(uintptr_t*)p);
		p += typeid(uintptr_t).size;
		break;
	case DW_EH_PE_udata2:
		result = *(cast(ushort*)p);
		p += typeid(ushort).size;
		break;
	case DW_EH_PE_udata4:
		result = *(cast(uint*)p);
		p += typeid(uint).size;
		break;
	case DW_EH_PE_udata8:
		result = cast(uintptr_t)*(cast(ulong*)p);
		p += typeid(ulong).size;
		break;
	case DW_EH_PE_sdata2:
		result = cast(uintptr_t)*(cast(short*)p);
		p += typeid(short).size;
		break;
	case DW_EH_PE_sdata4:
		result = cast(uintptr_t)*(cast(int*)p);
		p += typeid(int).size;
		break;
	case DW_EH_PE_sdata8:
		result = cast(uintptr_t)*(cast(long*)p);
		p += typeid(long).size;
		break;
	default:
		object.vrt_printf("%s: unhandled case type: %x\n", __FUNCTION__.ptr, encoding);
		exit(-1);
		break;
	}

	if (result) {
		switch (encoding & 0x70) {
		case DW_EH_PE_absptr:
			break;
		case DW_EH_PE_pcrel:
			result += cast(uintptr_t)pc;
			break;
		default:
			object.vrt_printf("%s: unhandled case encoding: %x\n", __FUNCTION__.ptr, encoding);
			exit(-1);
			break;
		}

		if (encoding & DW_EH_PE_indirect)
			result = *cast(uintptr_t*)result;
	}

	*data = p;

	return result;
}
