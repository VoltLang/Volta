module watt.io.file;

public import std.file : read, exists, remove, isFile;
public import std.file : SpanMode, dirEntries;

enum SearchStatus
{
	Continue,
	Halt,
}


void searchDir(string dirName, string glob, scope SearchStatus delegate(string) dg)
{
	foreach (file; dirEntries(dirName, glob, SpanMode.shallow)) {
		auto status = dg(file);
		if (status == SearchStatus.Halt) {
			break;
		}
	}
}
