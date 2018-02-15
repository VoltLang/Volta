module vls.server.diagnostic.diagnostic;

import ir = volta.ir;
import watt = watt.text.sink;
import json = watt.json;
import vls = vls.semantic.symbolGathererVisitor;
import c = core.c.stdlib;

struct Diagnostic
{
	uri: string;
	loc: ir.Location;
	message: string;
	level: i32;

	//! If non null, generated from a battery build.
	batteryRoot: string;

	//! Return a deep copy of this diagnostic.
	@property fn dup() Diagnostic
	{
		d: Diagnostic = this;
		d.uri     = new uri[..];
		d.loc     = dupLocation(loc);
		d.message = new message[..];
		if (batteryRoot.length > 0) {
			d.batteryRoot = new batteryRoot[..];
		}
		return d;
	}

}

//! Copies a `Location`.
fn dupLocation(loc: ir.Location) ir.Location
{
	newLoc: ir.Location = loc;
	newLoc.filename = new loc.filename[..];
	return newLoc;
}

struct Diagnostics
{
	arr: Diagnostic[];

	fn add(diagnostic: Diagnostic)
	{
		arr ~= diagnostic.dup;
	}

	fn clear()
	{
		arr = null;
	}

	fn response(uri: string) string
	{
		ss: watt.StringSink;
		ss.sink(`{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"`);
		ss.sink(uri);
		ss.sink(`","diagnostics":[`);
		foreach (i, d; arr) {
			ss.sink("{");
			ss.sink(`"range":`);
			vls.locationToRange(ref d.loc, ss.sink);
			ss.sink(`,"severity":`);
			ss.sink(new "${d.level},\"message\":\"");
			ss.sink(json.escapeString(d.message));
			ss.sink(`"}`);
			if (i < arr.length - 1) {
				ss.sink(`,`);
			}
		}
		ss.sink(`]}}`);
		return ss.toString();
	}
}
