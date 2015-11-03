module volt.main;

import watt.io.std : output;
import watt.io.file : read, searchDir;
import watt.path : dirName, baseName, dirSeparator;
import watt.text.format : format;
import watt.text.string : replace, indexOf;
import watt.conv : toString;

import ir = volt.ir.ir;
import volt.errors : makeError;
import volt.interfaces : VersionSet, Settings, Driver,
                         Frontend, LanguagePass, Backend,
                         Arch, Platform;
import volt.driver;

int main(string[] args)
{
	try {
		return realMain(args);
	} catch (object.Exception e) {
		output.writefln("\n%s\n%s:%s", e.msg, e.file, e.line);
		return 1;
	} catch (object.Throwable e) {
		output.writefln("\nThrowable: '???'\n%s:%s: '%s'",
		                e.throwFile, e.throwLine, e.msg);
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

	auto ver = new VersionSet();
	auto settings = new Settings(".");

	setDefault(settings);
	settings.internalD = true;
	settings.noBackend = true;

	string[] files;
	handleArgs(args[1 .. $], ref files, settings);

	settings.processConfigs(ver);

	auto driver = new VoltDriver(ver, settings);
	driver.addFiles(files);

	return driver.compile();
}

void handleArgs(string[] args, ref string[] files, Settings settings)
{
	foreach(arg; args) {
		version (Windows) {
			arg = arg.replace("/", "\\");
		}

		switch (arg) {
		case "-E":
			settings.removeConditionalsOnly = true;
			goto case;
		case "-S":
			settings.noBackend = true;
			continue;
		default:
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

void setDefault(Settings settings)
{
	// Only MinGW is supported.
	version (Windows) {
		settings.platform = Platform.MinGW;
	} else version (Linux) {
		settings.platform = Platform.Linux;
	} else version (OSX) {
		settings.platform = Platform.OSX;
	} else {
		static assert(false);
	}

	version (X86) {
		settings.arch = Arch.X86;
	} else version (X86_64) {
		settings.arch = Arch.X86_64;
	} else {
		static assert(false);
	}
}
