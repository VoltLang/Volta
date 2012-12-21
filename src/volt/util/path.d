// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.path;

version (Windows) {
	import core.sys.windows.windows : GetModuleFileNameA;
} else version (Posix) {
	import core.sys.posix.unistd : readlink;
} else {
	static assert(false);
}

import std.file : read, exists;
import std.path : dirName, dirSeparator;
import std.random : uniform;
import std.process : getenv;


/**
 * Used for turning module qualified names into file paths to open.
 */
string makeFilename(string dir, string[] names)
{
	auto ret = dir;

	foreach(name; names)
		ret ~= dirSeparator ~ name;
	ret ~= ".d";

	return ret;
}

/**
 * Generate a filename in a temporary directory that doesn't exist.
 *
 * Params:
 *   extension = a string to be appended to the filename. Defaults to an empty string.
 *
 * Returns: an absolute path to a unique (as far as we can tell) filename. 
 */
string temporaryFilename(string extension = "")
{
	version (Windows) {
		string prefix = getenv("TEMP") ~ '/';
	} else {
		string prefix = "/tmp/";
	}

	string filename;
	do {
		filename = randomString(32);
		filename = prefix ~ filename ~ extension;
	} while (exists(filename));

	return filename;
}

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

string getExePath()
{
	char[512] stack;

	version (Windows) {

		auto ret = GetModuleFileNameA(null, stack.ptr, 512);

	} else version (linux) {

		auto ret = readlink("/proc/self/exe", stack.ptr, 512);

	} else {
		static assert(false);
	}

	if (ret < 1)
		throw new Exception("could not get exe path");

	return dirName(stack[0 .. cast(size_t)ret]).idup;
}
