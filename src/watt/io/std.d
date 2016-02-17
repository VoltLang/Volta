module watt.io.std;

import std.stdio : writef, writefln;
import std.cstream : output = dout;
import std.cstream : error = derr;

import std.stream;

class OutputFileStream : BufferedFile
{
	this(string filename)
	{
		super(filename, FileMode.Out);
	}
}
