module watt.io.streams;

import std.stream : OutputStream;

import std.stream;
class OutputFileStream : BufferedFile
{
	this(string filename)
	{
		super(filename, FileMode.OutNew);
	}
}
