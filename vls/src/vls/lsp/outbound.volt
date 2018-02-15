module vls.lsp.outbound;

import vls.lsp.message;
import vls.lsp.constants;

import watt.conv;
import watt.io;
import watt.io.streams;
import watt.process.spawn;

import core.c.stdio;

version (OutputLog) {
	version (Windows) {
		enum HOMEVAR = "HOMEPATH";
	} else {
		enum HOMEVAR = "HOME";
	}
	import watt.math.random;
	import watt.io.seed;
	global outlog: OutputStream;
	global this()
	{
		rng: RandomGenerator;
		rng.seed(getHardwareSeedU32());
		outputPath := getEnv(HOMEVAR) ~ "/Desktop/vlsOutLog." ~ rng.randomString(4) ~ ".txt";
		outlog = new OutputFileStream(outputPath);
	}
	global ~this()
	{
		outlog.close();
	}
}

/**
 * Send `msg` to the client, with the appropriate headers.
 */
fn send(msg: string)
{
	version (Windows) {
		// TODO: Mirror the changes to the unix code and test etc.
		output.writefln("%s: %s", LENGTH_HEADER, msg.length);
		output.writeln("");
		output.write(msg);
		version (OutputLog) outlog.write(msg);
		output.flush();
		version (OutputLog) outlog.flush();
	} else {
		printf("%s: %d\r\n\r\n", LENGTH_HEADER.ptr, msg.length);
		printf("%s", toStringz(msg));
		fflush(stdout);
		version (OutputLog) {
			outlog.writef("%s: %s\r\n", LENGTH_HEADER, msg.length);
			outlog.write("\r\n");
			outlog.write(msg);
			outlog.flush();
		}
	}
}
