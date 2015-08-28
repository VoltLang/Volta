// Copyright © 2011, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module watt.path;

import std.random : uniform;
import std.process : environment;
import std.file : exists;

import watt.math.random;

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
		string prefix = environment.get("TEMP") ~ '/';
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

