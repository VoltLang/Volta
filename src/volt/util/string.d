module volt.util.string;

import std.utf;

import volt.exceptions;
import volt.token.location;

alias unescape!char unescapeString;
alias unescape!wchar unescapeWstring;
alias unescape!dchar unescapeDstring;

void[] unescape(T)(Location location, const T[] s)
{
	T[] output;

	bool escaping;
	foreach (c; s) {
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
				default:
					throw new CompilerError(location, "bad escape.");
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
		throw new CompilerError(location, "bad escape.");
	}

	return output;
}
