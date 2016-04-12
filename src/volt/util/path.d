// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.path;

import watt.conv : toString;
import watt.path : dirName, dirSeparator;

version (Posix) {
	version (Volt) import core.posix.unistd : getuid;
	else import core.sys.posix.unistd : getuid;
}


/**
 * Turns a qualified module name into a list of possible file paths.
 */
string[] genPossibleFilenames(string dir, string[] names)
{
	string[] paths;
	auto ret = dir;

	foreach (name; names) {
		ret ~= dirSeparator ~ name;
	}
	paths ~= ret ~ ".volt";
	paths ~= ret ~ dirSeparator ~ "package.volt";

	return paths;
}

/**
 * Get the temporary subdirectory name for this run of the compiler.
 */
string getTemporarySubdirectoryName()
{
	string name = "volta-";
	version (Posix) {
		name ~= toString(getuid());
	}
	return name;
}
