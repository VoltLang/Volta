// Copyright 2017-2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module vls.lsp.message;

import core.exception;
import watt.io;
import watt.conv;
import watt.text.string;
import watt.text.utf;

import vls.lsp.constants;

struct LspMessage
{
	contentLength: size_t;
	content: string;

	@property fn dup() LspMessage
	{
		msg: LspMessage;
		msg.contentLength = contentLength;
		msg.content = new content[..];
		return msg;
	}
}

// ReadChar(ref c) -- read character into c, returns false if function should return immediately.
alias ReadChar = scope dg(ref c: dchar) bool;
// Read content into the given message.
alias ReadMsg  = scope dg(ref msg: LspMessage);
// Should the parse loop continue?
alias Looping  = scope dg() bool;

fn parseLspMessageImpl(readChar: ReadChar, readMsg: ReadMsg, looping: Looping, out msg: LspMessage)
{
	newline := false;
	buf: char[];
	while (looping()) {
		c: dchar;
		continueExecution := readChar(ref c);
		if (!continueExecution) {
			break;
		}
		if (c == '\n') {
			if (newline) {
				if (msg.contentLength == 0) {
					throw new Exception("missing Content-Length header");
				} else {
					readMsg(ref msg);
					break;
				}
			} else if (buf.length != 0) {
				parseLspHeader(buf, ref msg);
			}
			newline = true;
		} else if (c != '\r') {
			encode(ref buf, c);
		}
	}
}

fn parseLspMessage(str: string, out msg: LspMessage) string
{
	originalStr := str;
	fn looping() bool { return str.length > 0; }
	fn readChar(ref c: dchar) bool { c = str[0]; str = str[1 .. $]; return true; }
	fn readMsg(ref m: LspMessage) {
		if (str.length < m.contentLength) {
			throw new Exception(new "content shorter than Content-Length ${str.length} ${m.contentLength} ${originalStr}");
		}
		m.content = str[0 .. m.contentLength];
		str = str[m.contentLength .. $];
	}
	parseLspMessageImpl(readChar, readMsg, looping, out msg);
	return str;
}

fn parseLspHeader(text: char[], ref msg: LspMessage)
{
	portions := split(cast(string)text, ':');
	if (portions.length != 2) {
		throw new Exception("headers are separated by a ':'");
	}
	switch (portions[0]) {
	case Header.Length:
		msg.contentLength = cast(size_t)toUlong(strip(portions[1]));
		break;
	case Header.Type:
		// We honestly don't care. Just assume UTF-8, no implementation uses anything else.
		break;
	default:
		throw new Exception(new "unknown header '${portions[0]}'");
	}
}
