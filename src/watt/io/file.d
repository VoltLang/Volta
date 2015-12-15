module watt.io.file;

import std.file : read, exists, remove;
version (Windows) import std.file : SpanMode, dirEntries;

// We only need this for globbing under Windows, so don't do a unix version.
version (Windows) void searchDir(string dirName, string glob, scope void delegate(string) dg)
{
	foreach (file; dirEntries(dirName, glob, SpanMode.shallow)) {
		dg(file);
	}
}
