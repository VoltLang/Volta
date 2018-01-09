/*#D*/
// Copyright © 2015-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2015-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0).
module volta.util.string;

import watt.conv : toInt, ConvException;
import watt.text.utf : encode;
import watt.text.format : format;
import watt.text.sink : StringSink;

import volta.interfaces;
import volta.errors;
import volta.ir.location;

//! Convert a @ref CRuntime to lower case string.
string cRuntimeToString(CRuntime cRuntime)
{
	final switch (cRuntime) with (CRuntime) {
	case None: return "none";
	case MinGW: return "mingw";
	case Glibc: return "glibc";
	case Darwin: return "darwin";
	case Microsoft:  return "microsoft";
	}
}

//! Convert @ref Platform to lower case string.
string platformToString(Platform platform)
{
	final switch (platform) with (Platform) {
	case MinGW: return "mingw";
	case MSVC:  return "msvc";
	case Linux: return "linux";
	case OSX:   return "osx";
	case Metal: return "metal";
	}
}

//! Convert @ref Arch to lower case string.
string archToString(Arch arch)
{
	final switch (arch) with (Arch) {
	case X86: return "x86";
	case X86_64: return "x86_64";
	}
}

bool isHex(dchar d)
{
	switch (d) {
	case 'a', 'b', 'c', 'd', 'e', 'f',
		 'A', 'B', 'C', 'D', 'E', 'F',
		 '0', '1', '2', '3', '4', '5',
		 '6', '7', '8', '9':
		return true;
	default:
		return false;
	}
}


immutable(void)[] unescapeString(ErrorSink errSink, ref in Location loc, const(char)[] s)
{
	version (Volt) {
		StringSink sink;
		auto output = sink.sink;
	} else {
		char[] output;
	}

	bool escaping, hexing;
	size_t unicoding;
	char[] hexchars;
	foreach (dchar c; s) {
		// \uXXXX
		if (unicoding) {
			if (!isHex(c)) {
				if (hexchars.length == unicoding) {
					uint i;
					try {
						i = cast(uint)toInt(hexchars, 16);
					} catch (ConvException) {
						errorExpected(errSink, /*#ref*/loc, "unicode codepoint specification");
						assert(false);  // @todo non aborting error handling
					}
					if (hexchars.length == 4) {
						encode(output, i);
					} else if (hexchars.length == 8) {
						encode(output, cast(ushort)i);
					} else {
						assert(false);
					}
					unicoding = 0;
					continue;
				} else {
					errorExpected(errSink, /*#ref*/loc, "unicode codepoint specification");
					assert(false);  // @todo non aborting error handling
				}
			}
			encode(/*#ref*/hexchars, c);
			if (hexchars.length == unicoding) {
				uint i;
				try {
					i = cast(uint)toInt(hexchars, 16);
				} catch (ConvException) {
					errorExpected(errSink, /*#ref*/loc, "unicode codepoint specification");
					assert(false); // @todo non aborting error handling
				}
				if (hexchars.length == 4) {
					encode(output, i);
				} else if (hexchars.length == 8) {
					encode(output, cast(ushort)i);
				} else {
					assert(false);
				}
				unicoding = 0;
				continue;
			}
			continue;
		}

		// \xXX
		if (hexing) {
			if (!isHex(c)) {
				errorExpected(errSink, /*#ref*/loc, "hex digit");
				assert(false); // @todo non aborting error handling
			}
			encode(/*#ref*/hexchars, c);
			if (hexchars.length == 2) {
				try {
					version (Volt) {
						output([cast(char)toInt(hexchars, 16)]);
					} else {
						output ~= cast(char)toInt(hexchars, 16);
					}
				} catch (ConvException) {
					errorExpected(errSink, /*#ref*/loc, "hex digit");
					assert(false); // @todo non aborting error handling
				}
				hexing = false;
				hexchars = null;
			}
			continue;
		}

		// \X
		if (escaping) {
			switch (c) {
				case '\'': encode(output, '\''); break;
				case '\"': encode(output, '\"'); break;
				case '\?': encode(output, '\?'); break;
				case '\\': encode(output, '\\'); break;
				case '$': encode(output, '$'); break;
				case 'a': encode(output, '\a'); break;
				case 'b': encode(output, '\b'); break;
				case 'f': encode(output, '\f'); break;
				case 'n': encode(output, '\n'); break;
				case 'r': encode(output, '\r'); break;
				case 't': encode(output, '\t'); break;
				case 'v': encode(output, '\v'); break;
				case '0': encode(output, '\0'); break;
				case 'x':
					escaping = false;
					hexing = true;
					hexchars = null;
					continue;
				case 'u':
					escaping = false;
					unicoding = 4;
					hexchars = null;
					continue;
				case 'U':
					escaping = false;
					unicoding = 8;
					hexchars = null;
					continue;
				// @todo Named character entities. http://www.w3.org/TR/html5/named-character-references.html
				default:
					string str = format("valid escape, found '\\%s'", c);
					errorExpected(errSink, /*#ref*/loc, str);
					assert(false); // @todo non aborting error handling
			}
			escaping = false;
			continue;
		}

		if (c == '\\') {
			escaping = true;
			continue;
		} else {
			encode(output, c);
		}
	}

	if (escaping) {
		errorExpected(errSink, /*#ref*/loc, "valid escape");
		assert(false); // @todo non aborting error handling
	}

	if (unicoding == 4) {
		errorExpected(errSink, /*#ref*/loc, "valid unicode escape, \\uXXXX");
		assert(false); // @todo non aborting error handling
	} else if (unicoding == 8) {
		errorExpected(errSink, /*#ref*/loc, "valid unicode escape, \\UXXXXXXXX");
		assert(false); // @todo non aborting error handling
	}

	version (Volt) {
		return cast(immutable(void)[]) sink.toString();
	} else {
		return cast(immutable(void)[]) output;
	}
}

/*!
 * Generate a hash.
 * djb2 algorithm stolen from http://www.cse.yorku.ca/~oz/hash.html
 *
 * This needs to correspond with the implementation
 * in vrt.string in the runtime. 
 */
uint hash(ubyte[] array)
{
	uint h = 5381;

	for (size_t i = 0; i < array.length; i++) {
		h = ((h << 5) + h) + array[i];
	}

	return h;
}

/*!
 * Returns a string that is s, with all '_' removed.
 *    "134_hello" => "134hello"
 *    "_" => ""
 */
string removeUnderscores(string s)
{
	auto output = new char[](s.length);
	size_t i;
	foreach (char c; s) {
		if (c == '_') {
			continue;
		}
		output[i++] = c;
	}
	version (Volt) {
		return i == s.length ? s : cast(string)new output[0 .. i];
	} else {
		return i == s.length ? s : output[0 .. i].idup;
	}
}
