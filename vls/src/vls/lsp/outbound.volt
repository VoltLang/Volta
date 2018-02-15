module vls.lsp.outbound;

import vls.lsp.message;
import vls.lsp.constants;

import watt.conv;
import watt.io;
import watt.io.streams;
import watt.process.spawn;

import core.c.stdio;
import core.rt.thread;

version (OutputLog) {
	version (Windows) {
		enum HOMEVAR = "USERPROFILE";
	} else {
		enum HOMEVAR = "HOME";
	}
	import watt.math.random;
	import watt.io.seed;
	global outlog: OutputStream;
}
global outputMutex: vrt_mutex*;
global this()
{
	outputMutex = vrt_mutex_new();
	version (OutputLog) {
		rng: RandomGenerator;
		rng.seed(getHardwareSeedU32());
		outputPath := getEnv(HOMEVAR) ~ "/Desktop/vlsOutLog." ~ rng.randomString(4) ~ ".txt";
		outlog = new OutputFileStream(outputPath);
	}
}
global ~this()
{
	vrt_mutex_delete(outputMutex);
	version (OutputLog) {
		outlog.close();
	}
}


/**
 * Send `msg` to the client, with the appropriate headers.
 *
 * Multithread safe insofar as send(AAA); on one thread while
 * send(BBB) runs on another will output AAA then BBB, or BBB then AAA.
 * They won't be intermixed.
 */
fn send(msg: string)
{
	vrt_mutex_lock(outputMutex);
	scope (exit) vrt_mutex_unlock(outputMutex);

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
