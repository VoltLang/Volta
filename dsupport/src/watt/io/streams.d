module watt.io.streams;

public import undead.stream : OutputStream, BufferedFile, FileMode;

class OutputFileStream : BufferedFile
{
	this(string filename)
	{
		super(filename, FileMode.OutNew);
	}
}
