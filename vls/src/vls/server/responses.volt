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

fn responseInitialized(ro: RequestObject) string
{
	msg := new "
		{
			\"jsonrcp\": \"2.0\",
			\"id\": ${ro.id.integer()},
			\"result\": {
				\"capabilities\": {
					\"textDocumentSync\": {
						\"openClose\": true,
						\"change\": 1,
						\"willSave\": false,
						\"willSaveWaitUntil\": false,
						\"save\": {
							\"includeText\": true
						}
					},
					\"hoverProvider\": true,
					\"completionProvider\": {
						\"resolveProvider\": false,
						\"triggerCharacters\": [\".\"]
					},
					\"signatureHelpProvider\": {
						\"triggerCharacters\": [\"(\", \",\"]
					},
					\"definitionProvider\": true,
					\"referencesProvider\": false,
					\"documentHighlightProvider\": false,
					\"documentSymbolProvider\": true,
					\"workspaceSymbolProvider\": false,
					\"codeActionProvider\": false,
					\"documentFormattingProvider\": false,
					\"documentRangeFormattingProvider\": false,
					\"documentOnTypeFormattingProvider\": {
						\"firstTriggerCharacter\": \"\",
						\"moreTriggerCharacters\": []
					},
					\"renameProvider\": false,
					\"executeCommandProvider\": {
						\"commands\": []
					}
				}
			}
		}";
	return compress(msg);
}

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

fn responseShutdown(ro: RequestObject) string
{
	msg := new "
		{
			\"jsonrcp\": \"2.0\",
			\"id\":${ro.id.integer()},
			\"result\": {
			}
		}";
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

fn notificationDiagnostic(uri: string, loc: Location, errmsg: string, diagnosticLevel: i32) string
{
	ss: StringSink;
	ss.sink(`{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"`);
	ss.sink(uri);
	ss.sink(`","diagnostics":[{"range":`);
	locationToRange(ref loc, ss.sink);
	ss.sink(new ",\"severity\":${diagnosticLevel},\"message\":\"");
	ss.sink(json.escapeString(errmsg));
	ss.sink(`"}]}}`);
	return compress(ss.toString());
}

fn notificationNoDiagnostic(uri: string) string
{
	msg := new "{
		\"jsonrpc\": \"2.0\",
		\"method\": \"textDocument/publishDiagnostics\",
		\"params\": {
			\"uri\": \"${uri}\",
			\"diagnostics\": []
		}
	}";
	return compress(msg);
}

private:

//! Remove all whitespace from a string.
fn compress(s: string) string
{
	escaping, inString: bool;
	ss: StringSink;
	foreach (c: dchar; s) {
		if (c == '"' && !escaping) {
			inString = !inString;
		}
		escaping = c == '\\';
		if (!isWhite(c) || inString) {
			ss.sink(encode(c));
		}
	}
	return ss.toString();
}