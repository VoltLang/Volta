// Copyright 2017-2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module vls.lsp.outbound;

import vls.lsp.message;
import vls.lsp.constants;

import watt.conv;
import watt.io;
import watt.io.streams;
import watt.process.spawn;
import watt.text.sink;
import watt.path;

version (Windows) import core.c.windows;
import core.exception;
import core.c.stdio;
import core.rt.thread;
import core.rt.format;

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
version (Windows) global windowsOutput: WindowsOutput;
global this()
{
	outputMutex = vrt_mutex_new();
	version (Windows) windowsOutput = new WindowsOutput();
	version (OutputLog) {
		rng: RandomGenerator;
		rng.seed(getHardwareSeedU32());
		outputPath := getEnv(HOMEVAR) ~ "/Desktop/vlsOutLog." ~ rng.randomString(4) ~ baseName(getExecFile()) ~ ".txt";
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

version (Windows) {
	class WindowsOutput : OutputStream
	{
	private:
		mHandle: HANDLE;

	public:
		this()
		{
			mHandle = GetStdHandle(STD_OUTPUT_HANDLE);
		}

	public:
		override @property fn isOpen() bool
		{
			return true;
		}

		override fn close()
		{
		}

		override fn put(c: dchar)
		{
			WriteFile(mHandle, cast(LPCVOID)&c, 1, null, null);
		}

		override fn write(s: scope const(char)[])
		{
			dwBytesWritten: DWORD;
			bResult := WriteFile(mHandle, cast(LPCVOID)s.ptr, cast(DWORD)s.length, &dwBytesWritten, null);
			if (bResult == 0) {
				err := GetLastError();
				throw new Exception(new "WriteFile failure ${err}");
			}
			if (dwBytesWritten != cast(DWORD)s.length) {
				throw new Exception("WriteFile didn't write all bytes");
			}
		}

		override fn flush()
		{
			FlushFileBuffers(mHandle);
		}
	}
}

fn send(msg: string)
{
	version (Windows) {
		send(msg, windowsOutput);
	} else {
		send(msg, output);
	}
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

	ss: StringSink;
	ss.sink(Header.Length);
	ss.sink(": ");
	vrt_format_u64(ss.sink, msg.length);
	ss.sink("\r\n\r\n");
	ss.sink(msg);

	str := ss.toString();
	outs.write(str);
	outs.flush();
	version (OutputLog) outlog.write(str);
	version (OutputLog) outlog.flush();
}
