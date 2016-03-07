module volt.util.string;

import watt.conv : toInt, ConvException;
import watt.text.utf : encode;

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


immutable(void)[] unescapeString(Location location, const(char)[] s)
{
	char[] output;

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
						throw makeExpected(location, "unicode codepoint specification");
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
					throw makeExpected(location, "unicode codepoint specification");
				}
			}
			encode(hexchars, c);
			if (hexchars.length == unicoding) {
				uint i;
				try {
					i = cast(uint)toInt(hexchars, 16);
				} catch (ConvException) {
					throw makeExpected(location, "unicode codepoint specification");
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
				throw makeExpected(location, "hex digit");
			}
			encode(hexchars, c);
			if (hexchars.length == 2) {
				try {
					output ~= cast(char)toInt(hexchars, 16);
				} catch (ConvException) {
					throw makeExpected(location, "hex digit");
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
					throw makeExpected(location, "valid escape");
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
		throw makeExpected(location, "valid escape");
	}

	if (unicoding == 4) {
		throw makeExpected(location, "valid unicode escape, \\uXXXX");
	} else if (unicoding == 8) {
		throw makeExpected(location, "valid unicode escape, \\UXXXXXXXX");
	}

	return cast(immutable(void)[]) output;
}

/**
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

/**
 * Take a doc comment and remove comment cruft from it.
 */
string cleanComment(string comment, out bool isBackwardsComment)
{
	assert(comment.length > 2);
	char commentChar;
	if (comment[0..2] == "**") {
		commentChar = '*';
	} else if (comment[0..2] == "++") {
		commentChar = '+';
	} else if (comment[0..2] == "//") {
		commentChar = '/';
	} else {
		assert(false, comment);
	}

	char[] outbuf;
	bool ignoreWhitespace = true;
	foreach (i, dchar c; comment) {
		if (i == comment.length - 1 && commentChar != '/' && c == '/') {
			continue;
		}
		if (i == 2 && c == '<') {
			isBackwardsComment = true;
			continue;  // Skip the '<'.
		}
		switch (c) {
		case '*', '+', '/':
			if (c == commentChar && ignoreWhitespace) {
				break;
			}
			goto default;
		case ' ', '\t':
			if (!ignoreWhitespace) {
				goto default;
			}
			break;
		case '\n':
			ignoreWhitespace = true;
			outbuf ~= '\n';
			break;
		default:
			ignoreWhitespace = false;
			encode(outbuf, c);
			break;
		}
	}

	version (Volt) {
		return cast(immutable(char)[])new outbuf[0 .. $];
	} else {
		return outbuf.idup;
	}
}
