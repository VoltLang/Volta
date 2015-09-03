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

	string[] files;
	handleArgs(args[1 .. $], ref files);

	foreach (file; files) {
		try {
			doFile(file);
		} catch (object.Exception e) {
			output.writefln("\n%s\n%s:%s", e.message, e.file, e.line);
		} catch (object.Throwable e) {
			output.writefln("\nThrowable: '???'\n%s:%s: '%s'",
			                e.throwFile, e.throwLine, e.message);
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

void handleArgs(string[] args, ref string[] files)
{
	foreach(arg; args) {
		version (Windows) {
			arg = arg.replace("/", "\\");
		}

		auto barg = baseName(arg);
		if (barg.length > 2 && barg[0 .. 2] == "*.") {

			auto dir = dirName(arg);

			void file(string str) {
				files ~= dir ~ dirSeparator ~ str;
			}

			searchDir(dir, barg, file);
			continue;
		}

		files ~= arg;
	}
}
