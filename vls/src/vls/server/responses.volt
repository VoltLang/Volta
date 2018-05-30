module vls.server.responses;

import core.rt.format;

import watt.conv;
import watt.text.string;
import watt.text.sink;
import watt.text.ascii;
import watt.text.utf;
import json = watt.json;

import volta.interfaces;
import volta.ir.location;
import ir = volta.ir;
import volta.visitor.visitor : accept;

import vls.lsp;
import vls.parsing.documentManager;
import vls.semantic.symbolGathererVisitor;
import vls.semantic.completion;
import vls.server;

fn responseNull(ro: RequestObject) string
{
	msg := new "{\"jsonrcp\":\"2.0\",\"id\":${ro.id.integer()}, \"result\": null}";
	return compress(msg);
}

fn responseError(ro: RequestObject, err: Error) string
{
	msg := new "{\"jsonrcp\":\"2.0\",\"id\":${ro.id.integer()},\"error\":{\"code\":${err.code},\"message\":${err.message}}}";
	return compress(msg);
}

fn responseSymbolInformation(theServer: VoltLanguageServer, ro: RequestObject, uri: string, mod: ir.Module) string
{
	theServer.sgv.symbols = null;
	ss: StringSink;
	ss.sink(`{"jsonrcp":"2.0","id":`);
	vrt_format_i64(ss.sink, ro.id.integer());
	ss.sink(`,"result":[`);
	accept(mod, theServer.sgv);
	foreach (i, symbol; theServer.sgv.symbols) {
		symbol.jsonString(uri, ss.sink);
		if (i < theServer.sgv.symbols.length - 1) {
			ss.sink(", ");
		}
	}
	ss.sink("]}");
	return compress(ss.toString());
}

fn responseCompletionInformation(theServer: VoltLanguageServer, ro: RequestObject, uri: string, mod: ir.Module) string
{
	return compress(getCompletionResponse(ro, uri, theServer));
}

fn responseSignatureHelp(theServer: VoltLanguageServer, ro: RequestObject, uri: string, mod: ir.Module) string
{
	return compress(getSignatureHelpResponse(ro, uri, theServer));
}

fn responseHover(theServer: VoltLanguageServer, ro: RequestObject, uri: string, mod: ir.Module) string
{
	return compress(getHoverResponse(ro, uri, theServer));
}

fn responseGotoDefinition(theServer: VoltLanguageServer, ro: RequestObject, uri: string, mod: ir.Module) string
{
	return compress(getGotoDefinitionResponse(ro, uri, theServer));
}
