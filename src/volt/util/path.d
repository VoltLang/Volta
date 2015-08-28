// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.path;

version (Windows) {
	import core.sys.windows.windows : GetModuleFileNameA;
} else version (darwin) {
	extern(C) int _NSGetExecutablePath(char*, uint*);
} else version (Posix) {
	import core.sys.posix.unistd : readlink;
} else {
	static assert(false);
}

import std.file : read, exists;
import std.string : indexOf;
import std.array : replace;
import std.path : dirName, dirSeparator;
import std.random : uniform;
import std.process : environment;


/**
 * Turns a qualified module name into a list of possible file paths.
 */
string[] genPossibleFilenames(string dir, string[] names)
{
	string[] paths;
	auto ret = dir;

	foreach(name; names)
		ret ~= dirSeparator ~ name;
	paths ~= ret ~ ".volt";
	paths ~= ret ~ dirSeparator ~ "package.volt";

	return paths;
}

/**
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
		if (ret != 0 || size == 0)
			ret = -1;
		else
			ret = cast(int)size;

	} else {

		static assert(false);

	}

	if (ret < 1)
		throw new Exception("could not get exe path");

	return dirName(stack[0 .. cast(size_t)ret]).idup;
}
