/*#D*/
// Copyright 2011, Bernard Helyer.
// Copyright 2012, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volt.util.path;

import watt.conv : toString;
import watt.path : mkdir, dirName, dirSeparator, temporaryFilename;
import watt.io.file : remove, exists;
import watt.text.sink : StringSink;
import watt.text.format : format;

version (Posix) {
	version (Volt) import core.c.posix.unistd : getuid;
	else import core.sys.posix.unistd : getuid;
}


/*!
 * Does the same as unix's "mkdir -p" command.
 */
void mkdirP(string name)
{
	if (name == "" || name is null) {
		return;
	}

	auto str = dirName(name);
	if (str != ".") {
		mkdirP(str);
	}

	if (!exists(name)) {
		mkdir(name);
	}
}

/*!
 * Turns a qualified module name into a list of possible file paths.
 */
string[] genPossibleFilenames(string dir, string[] names, string suffix)
{
	auto paths = new string[](2);
	StringSink ret;
	ret.sink(dir);

	foreach (name; names) {
		ret.sink(dirSeparator);
		ret.sink(name);
	}
	paths[0] = format("%s%s", ret.toString(), suffix);
	paths[1] = format("%s%spackage%s", ret.toString(), dirSeparator, suffix);

	return paths;
}

/*!
 * Get the temporary subdirectory name for this run of the compiler.
 */
string getTemporarySubdirectoryName()
{
	StringSink name;
	name.sink("volta-");
	version (Posix) {
		name.sink(toString(getuid()));
	}
	return name.toString();
}

/*!
 * Helper class to manage temporary files.
 */
class TempfileManager
{
protected:
	string mSubdir;
	string[] mTemporaryFiles;


public:
	/*!
	 * Uses @ref volt.util.path.getTemporarySubdirectoryName to get the
	 * system temporary directory.
	 *
	 * @SideEffect Sets @ref mSubdir.
	 */
	this()
	{
		mSubdir = getTemporarySubdirectoryName();
	}

	/*!
	 * Creates a temporary file name with the given ending.
	 *
	 * The file will be located in the system temporary directory
	 * as specified by @ref volt.util.path.getTemporarySubdirectoryName.
	 *
	 * @param ending The file ending for the temporary file.
	 * @SideEffect Adds return to @ref mTemporaryFiles.
	 */
	string getTempFile(string ending)
	{
		string ret = temporaryFilename(ending, mSubdir);
		mTemporaryFiles ~= ret;
		return ret;
	}

	/*!
	 * Remove all tempfiles tracked by this manager.
	 *
	 * @SideEffect Sets @ref mTemporaryFiles to null.
	 */
	void removeTempfiles()
	{
		foreach (f; mTemporaryFiles) {
			if (f.exists()) {
				f.remove();
			}
		}

		mTemporaryFiles = null;
	}
}
