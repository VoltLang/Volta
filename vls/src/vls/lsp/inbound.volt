/**
 * Handles inbound communication between the client (editor) and the server (us).
 */
module vls.lsp.inbound;

import core.exception : Exception;
import watt.io : input, error;
import watt.io.streams;
import watt.conv : toUlong;
import watt.text.utf : encode;
import watt.text.string : split, strip;
import watt.text.format : format;
import watt.process.spawn : getEnv;

import vls.lsp.constants;
import vls.lsp.message;

version (InputLog) {
	version (Windows) {
		enum HOMEVAR = "HOMEPATH";
	} else {
		enum HOMEVAR = "HOME";
	}
	import watt.math.random;
	import watt.io.seed;
	global inlog: OutputStream;
	global this()
	{
		rng: RandomGenerator;
		rng.seed(getHardwareSeedU32());
		inputPath := getEnv(HOMEVAR) ~ "/Desktop/vlsInLog." ~ rng.randomString(4) ~ ".txt";
		inlog = new OutputFileStream(inputPath);
	}
	global ~this()
	{
		inlog.close();
	}
}

/**
 * Listen for request objects, dispatch appropriately.
 * Returns: true if we should continue to listen, false otherwise.
 */
fn listen(handle: dg(LspMessage) bool, inputStream: InputStream) bool
{
	if (inputStream.eof()) {
		return STOP_LISTENING;
	}
	buf: char[];
	newline: bool;
	msg: LspMessage;
	while (true) {
		c := inputStream.get();
		if (inputStream.eof()) {
			break;
		}
		version (InputLog) {
			inlog.put(c);
			inlog.flush();
		}
		if (c == '\n') {
			if (newline) {
				// Beginning of content.
				if (msg.contentLength == 0) {
					throw new Exception("missing Content-Length header");
				} else {
					msg.content = readContent(msg.contentLength, inputStream);
					return handle(msg);
				}
			} else if (buf.length != 0) {
				parseHeader(buf, ref msg);
			}
			newline = true;
		} else if (c != '\r') {
			encode(ref buf, c);
		}
	}
	return false;
}

private:

/// Read a string from the next `length` bytes of stdin, or throw an Exception.
fn readContent(length: size_t, inputStream: InputStream) string
{
	buf := new u8[](length);
	read: size_t;

	while (read < length) {
		if (inputStream.eof()) {
			throw new Exception("unexpected EOF");
		}

		// Start from the amount that we have read.
		r := inputStream.read(buf[read .. $]);
		read += r.length;
	}

	str := cast(string)buf;
	version (InputLog) {
		inlog.write(str);
		inlog.flush();
	}
	return str;
}

fn parseHeader(text: char[], ref msg: LspMessage)
{
	portions := split(cast(string)text, ':');
	if (portions.length != 2) {
		throw new Exception("headers are separated by a ':'");
	}
	switch (portions[0]) {
	case LENGTH_HEADER:
		msg.contentLength = cast(size_t)toUlong(strip(portions[1]));
		break;
	case TYPE_HEADER:
		// We honestly don't care. Just assume UTF-8, no implementation uses anything else.
		break;
	default:
		throw new Exception(new "unknown header '${portions[0]}'");
	}
}
