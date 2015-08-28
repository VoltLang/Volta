// Copyright © 2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module watt.math.random;

import std.random : uniform;

/**
 * Generate a random string `length` characters long.
 */
string randomString(size_t length)
{
	auto str = new char[length];
	foreach (i; 0 .. length) {
		char c;
		switch (uniform(0, 3)) {
			case 0:
				c = uniform!("[]", char, char)('0', '9');
				break;
			case 1:
				c = uniform!("[]", char, char)('a', 'z');
				break;
			case 2:
				c = uniform!("[]", char, char)('A', 'Z');
				break;
			default:
				assert(false);
		}
		str[i] = c;
	}
	return str.idup;    
}
