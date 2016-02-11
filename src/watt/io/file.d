module watt.io.file;

import std.file : read, exists, remove;
import std.file : SpanMode, dirEntries;

void searchDir(string dirName, string glob, scope void delegate(string) dg)
{
	foreach (file; dirEntries(dirName, glob, SpanMode.shallow)) {
		dg(file);
	}
}
