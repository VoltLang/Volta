// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.path;

import watt.path : dirName, dirSeparator;


/**
 * Turns a qualified module name into a list of possible file paths.
 */
string[] genPossibleFilenames(string dir, string[] names)
{
	string[] paths;
	auto ret = dir;

	foreach(name; names) {
		ret ~= dirSeparator ~ name;
	}
	paths ~= ret ~ ".volt";
	paths ~= ret ~ dirSeparator ~ "package.volt";

	return paths;
}
