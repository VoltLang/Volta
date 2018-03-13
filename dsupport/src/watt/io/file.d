module watt.io.file;

public import std.file : read, exists, remove, isFile;
public import std.file : SpanMode, dirEntries;

void searchDir(string dirName, string glob, scope void delegate(string) dg)
{
	foreach (file; dirEntries(dirName, glob, SpanMode.shallow)) {
		dg(file);
	}
}
