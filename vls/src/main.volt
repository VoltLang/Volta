module main;

import watt = [watt.text.getopt, watt.io.streams, watt.io];

import lsp = vls.lsp;
import vls.server;

fn main(args: string[]) i32
{
	inputStream: watt.InputStream = watt.input;
	inputPath, modulePath: string;
	wait, help: bool;
	watt.getopt(ref args, "input", ref inputPath);
	watt.getopt(ref args, "modulePath", ref modulePath);
	watt.getopt(ref args, "help", ref help);
	watt.getopt(ref args, "wait", ref wait);

	if (inputPath !is null) {
		inputStream = new watt.InputFileStream(inputPath);
	}

	if (help) {
		printUsage();
		return 0;
	}

	if (wait) {
		watt.writeln("Press enter to begin...");
		watt.input.readln();
	}

	server := new VoltLanguageServer(args[0], modulePath);
	while (lsp.listen(server.handle, inputStream)) {
	}
	return server.retval;
}

fn printUsage()
{
	watt.writeln("VLS: Volt Language Server");
	watt.writeln("usage: vls [options]");
	watt.writeln("VLS is intended to be run by a language client, like");
	watt.writeln("Visual Studio Code. These options are for VLS debugging purposes.");
	watt.writeln("");
	watt.writeln("--input <file>       specify a file to read input from, rather than stdin.");
	watt.writeln("--modulePath <path>  specify a path to look for import modules from.");
	watt.writeln("--wait               wait for a line from stdin before starting.");
	watt.writeln("--help               display this list of options and exit.");
}
