module main;

import core.rt.thread;
import watt = [watt.text.getopt, watt.io.streams, watt.io];

import lsp = vls.lsp;
import vls.server;

import modules = vls.modules;
import inputThread = vls.lsp.inputThread;
import messageHopper = vls.messageHopper;

fn main(args: string[]) i32
{
	inputStream: watt.InputStream = watt.input;
	inputPath, modulePath: string;
	wait, help: bool;
	watt.getopt(ref args, "input", ref inputPath);
	if (watt.getopt(ref args, "modulePath", ref modulePath)) {
		modules.setModulePath(modulePath);
	}
	watt.getopt(ref args, "help", ref help);
	watt.getopt(ref args, "wait", ref wait);

	if (inputPath !is null) {
		inputThread.setInputFile(inputPath);
	} else {
		inputThread.setStandardInput();
	}

	if (help) {
		printUsage();
		return 0;
	}

	if (wait) {
		watt.writeln("Press enter to begin...");
		watt.input.readln();
	}

	ithread := vrt_thread_start_fn(inputThread.threadFunction);
	server := new VoltLanguageServer(args[0], modulePath);
	while (!inputThread.done()) {
		message: lsp.LspMessage;
		if (inputThread.getMessage(out message)) {
			ro := new lsp.RequestObject(message.content);
			messageHopper.add(ro);
		}
		messageHopper.process(server.handle);
	}
	vrt_thread_join(ithread);
	return server.retval;
}

fn printUsage()
{
	watt.writeln("VLS: Volt Language Server");
	watt.writeln("usage: vls [options]");
	watt.writeln("VLS is not intended to be run by hand.");
	watt.writeln("These options are for internal purposes.");
	watt.writeln("");
	watt.writeln("--input <file>       specify a file to read input from, rather than stdin.");
	watt.writeln("--modulePath <path>  specify a path to look for import modules from.");
	watt.writeln("--wait               wait for a line from stdin before starting.");
	watt.writeln("--help               display this list of options and exit.");
}
