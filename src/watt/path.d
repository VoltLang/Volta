// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module watt.path;

import std.random : uniform;
import std.process : environment;
import std.file : exists, mkdir, mkdirRecurse;
import std.path : baseName, dirName, dirSeparator;


import watt.math.random;

/*!
 * Generate a filename in a temporary directory that doesn't exist.
 *
 * Params:
 *   extension = a string to be appended to the filename. Defaults to an empty string.
 *   subdir = a directory in the temporary directory to place the file.
 *
 * Returns: an absolute path to a unique (as far as we can tell) filename. 
 */
string temporaryFilename(string extension = "", string subdir = "")
{
	version (Windows) {
		string prefix = environment.get("TEMP") ~ '/';
	} else {
		string prefix = "/tmp/";
	}

	if (subdir != "") {
		prefix ~= subdir ~ "/";
		mkdirRecurse(prefix);
	}

	string filename;
	do {
		filename = randomString(32);
		filename = prefix ~ filename ~ extension;
	} while (exists(filename));

	return filename;
}

version (Windows) {
	import core.sys.windows.windows : GetModuleFileNameA;
} else version (linux) {
	import core.sys.posix.unistd : readlink;
} else version (darwin) {
	extern(C) int _NSGetExecutablePath(char*, uint*);
}

/*!
 * Return the path to the dir that the executable is in.
 */
string getExecDir()
{
	char[512] stack;

	version (Windows) {

		auto ret = GetModuleFileNameA(null, stack.ptr, 512);

	} else version (linux) {

		auto ret = readlink("/proc/self/exe", stack.ptr, 512);

	} else version (darwin) {

		uint size = cast(uint)stack.length;
		auto ret = _NSGetExecutablePath(stack.ptr, &size);
		if (ret != 0 || size == 0) {
			ret = -1;
		} else {
			ret = cast(int)size;
		}

	} else {

		static assert(false);

	}

	if (ret < 1) {
		throw new Exception("could not get exe path");
	}

	return dirName(stack[0 .. cast(size_t)ret]).idup;
}
