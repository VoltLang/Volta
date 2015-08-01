module volt.main;

import watt.io.std : output;
import watt.io.file : read;
import watt.conv : toString;

import volt.token.location : Location;
import volt.parser.parser : Parser;

int main(string[] args)
{
	try {
		return realMain(args);
	} catch (object.Exception e) {
		output.writefln("\n%s\n%s:%s", e.message, e.file, e.line);
		return 1;
	} catch (object.Throwable e) {
		output.writefln("\nThrowable: '???'\n%s:%s: '%s'",
		                /*e.classinfo.mangledName,*/ toString(e.throwFile),
		                e.throwLine, e.message);
		return 1;
	}
	assert(false);
}

int realMain(string[] args)
{
	if (args.length == 1) {
		output.writefln("usage: %s [files]\n", args[0]);
		return 1;
	}
	foreach (arg; args[1 .. args.length]) {
		try {
			doFile(arg);
		} catch (object.Exception e) {
			output.writefln("\n%s\n%s:%s", e.message, e.file, e.line);
		} catch (object.Throwable e) {
			output.writefln("\nThrowable: '???'\n%s:%s: '%s'",
			                /*e.classinfo.mangledName,*/ toString(e.throwFile),
			                e.throwLine, e.message);
		}
	}
	return 0;
}

void doFile(string arg)
{
	Location loc;
	loc.filename = arg;

	auto p = new Parser();
	auto src = cast(string) read(loc.filename);
	auto m = p.parseNewFile(src, loc);
}
