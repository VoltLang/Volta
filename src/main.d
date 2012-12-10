// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module main;

import std.stdio : writefln;

import volt.license;
import volt.interfaces;
import volt.controller;


int main(string[] args)
{
	auto settings = new Settings();
	if (!filterArgs(args, settings))
		return 0;

	if (args.length <= 1) {
		writefln("%s: no input files", args[0]);
		return 0;
	}

	version (none) if (args.length > 2) {
		/// @todo fix this.
		writefln("%s, too many input files", args[0]);
		return 1;
	}

	auto vc = new VoltController(settings);
	vc.addFiles(args[1 .. $]);
	int ret = vc.compile();
	vc.close();

	return ret;
}

bool filterArgs(ref string[] args, Settings settings)
{
	void delegate(string) argHandler;
	string[] ret;
	int i;
	ret.length = args.length;

	// Handlers.
	void outputFile(string file) {
		settings.outputFile = file;
	}

	// Skip the first argument.
	ret[i++] = args[0];

	foreach(arg; args[1 .. $])  {
		if (argHandler !is null) {
			argHandler(arg);
			argHandler = null;
			continue;
		}

		switch (arg) {
		case "-license", "--license":
			return printLicense();
		case "-o":
			argHandler = &outputFile;
			continue;
		case "-w":
			settings.warningsEnabled = true;
			continue;
		case "-d":
			settings.debugEnabled = true;
			continue;
		case "--no-backend":
		case "-S":
			settings.noBackend = true;
			continue;
		default:
		}

		ret[i++] = arg;
	}

	ret.length = i;
	args = ret;
	return true;
}

bool printLicense()
{
	foreach(license; licenseArray)
		writefln(license);
	return false;
}

