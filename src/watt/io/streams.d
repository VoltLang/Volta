module watt.io.streams;

import std.stream : OutputStream, BufferedFile, FileMode;

class OutputFileStream : BufferedFile
{
	this(string filename)
	{
		super(filename, FileMode.OutNew);
	}
}
