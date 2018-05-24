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

fn send(msg: string)
{
	send(msg, output);
}

/**
 * Send `msg` to the client, with the appropriate headers,
 * over the given `OutputStream`.
 *
 * Multithread safe insofar as send(AAA); on one thread while
 * send(BBB) runs on another will output AAA then BBB, or BBB then AAA.
 * They won't be intermixed.
 */
fn send(msg: string, outs: OutputStream)
{
	vrt_mutex_lock(outputMutex);
	scope (exit) vrt_mutex_unlock(outputMutex);

	version (Windows) {
		outs.writefln("%s: %s", Header.Length, msg.length);
		outs.writeln("");
		outs.write(msg);
		version (OutputLog) outlog.write(msg);
		outs.flush();
		version (OutputLog) outlog.flush();
	} else {
		static assert(false, "implement outbound.send for *nix");
		/*
		printf("%s: %d\r\n\r\n", Header.Length.ptr, msg.length);
		printf("%s", toStringz(msg));
		fflush(stdout);
		version (OutputLog) {
			outlog.writef("%s: %s\r\n", Header.Length, msg.length);
			outlog.write("\r\n");
			outlog.write(msg);
			outlog.flush();
		}
		*/
	}
}
