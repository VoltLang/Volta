/*#D*/
module volt.util.string;

import watt.conv : toInt, ConvException;
import watt.text.utf : encode;
import watt.text.format : format;
import watt.text.sink : StringSink;

import volt.errors;
import volt.token.location;


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


immutable(void)[] unescapeString(ref in Location loc, const(char)[] s)
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
						throw makeExpected(/*#ref*/loc, "unicode codepoint specification");
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
					throw makeExpected(/*#ref*/loc, "unicode codepoint specification");
				}
			}
			encode(/*#ref*/hexchars, c);
			if (hexchars.length == unicoding) {
				uint i;
				try {
					i = cast(uint)toInt(hexchars, 16);
				} catch (ConvException) {
					throw makeExpected(/*#ref*/loc, "unicode codepoint specification");
				}
				if (hexchars.length == 4) {
					encode(/*#ref*/output, i);
				} else if (hexchars.length == 8) {
					encode(/*#ref*/output, cast(ushort)i);
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
				throw makeExpected(/*#ref*/loc, "hex digit");
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
					throw makeExpected(/*#ref*/loc, "hex digit");
				}
				hexing = false;
				hexchars = null;
			}
			continue;
		}

		// \X
		if (escaping) {
			switch (c) {
				case '\'': encode(/*#ref*/output, '\''); break;
				case '\"': encode(/*#ref*/output, '\"'); break;
				case '\?': encode(/*#ref*/output, '\?'); break;
				case '\\': encode(/*#ref*/output, '\\'); break;
				case '$': encode(/*#ref*/output, '$'); break;
				case 'a': encode(/*#ref*/output, '\a'); break;
				case 'b': encode(/*#ref*/output, '\b'); break;
				case 'f': encode(/*#ref*/output, '\f'); break;
				case 'n': encode(/*#ref*/output, '\n'); break;
				case 'r': encode(/*#ref*/output, '\r'); break;
				case 't': encode(/*#ref*/output, '\t'); break;
				case 'v': encode(/*#ref*/output, '\v'); break;
				case '0': encode(/*#ref*/output, '\0'); break;
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
					throw makeExpected(/*#ref*/loc, str);
			}
			escaping = false;
			continue;
		}

		if (c == '\\') {
			escaping = true;
			continue;
		} else {
			encode(/*#ref*/output, c);
		}
	}

	if (escaping) {
		throw makeExpected(/*#ref*/loc, "valid escape");
	}

	if (unicoding == 4) {
		throw makeExpected(/*#ref*/loc, "valid unicode escape, \\uXXXX");
	} else if (unicoding == 8) {
		throw makeExpected(/*#ref*/loc, "valid unicode escape, \\UXXXXXXXX");
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
