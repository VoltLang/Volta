module volt.main;

import watt.io.std : output;
import watt.io.file : read, searchDir;
import watt.path : dirName, baseName, dirSeparator;
import watt.text.string : replace, indexOf;
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
		                e.throwFile, e.throwLine, e.message);
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
		auto ret = expandIfGlob(arg);
		foreach (file; ret) {
			try {
				doFile(file);
			} catch (object.Exception e) {
				output.writefln("\n%s\n%s:%s", e.message, e.file, e.line);
			} catch (object.Throwable e) {
				output.writefln("\nThrowable: '???'\n%s:%s: '%s'",
				                e.throwFile, e.throwLine, e.message);
			}
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

string[] expandIfGlob(string input)
{
	version (Windows) {
		input = input.replace("/", "\\");
	}

	if (isGlob(input)) {
		auto dir = dirName(input);
		auto name = baseName(input);

		// Just let it explode later on.
		if (isGlob(dir)) {
			return [input];
		}

		string[] ret;

		void dg(string file) {
			ret ~= dir ~ dirSeparator ~ file;
			version (Windows) {
				ret[$-1] = ret[$-1].replace("\\", "/");
			}
		}

		searchDir(dir, name, dg);

		return ret;
	}

	return [input];
}

bool isGlob(string str)
{
	return str.indexOf("*") >= 0;
}
