module vls.server;

import watt.io;
import watt.io.streams;
import watt.path;
import watt.text.path;
import watt.io.file;
import watt.process.environment;
import json = watt.json;

import volta.interfaces;
import volta.settings;
import volta.parser.base;
import volta.parser.toplevel;
import volta.parser.errors;
import volta.parser.parser;
import volta.token.source;
import volta.token.lexer;
import ir = volta.ir;

import vls.lsp;
import vls.server.responses;
import vls.util.simpleCache;
import vls.semantic.symbolGathererVisitor;

import documents = vls.documents;
import parser    = vls.parser;
import modules   = vls.modules;

class VoltLanguageServer : ErrorSink
{
public:
	//! Used for testing external modules, unused in usual operation.
	modulePath: string;
	settings: Settings;
	importCache: SimpleImportCache;
	sgv: SymbolGathererVisitor;

	retval: i32;

	pathToVolta: string;
	pathToWatt: string;
	additionalPaths: string[string];

public:
	this(argZero: string, modulePath: string)
	{
		execDir := getExecDir();

		this.modulePath = modulePath;
		settings = new Settings(argZero, execDir);
		settings.warningsEnabled = true;
		sgv = new SymbolGathererVisitor();
	}

	/// LSP listen callback.
	fn handle(msg: LspMessage) bool
	{
		return handleRO(new RequestObject(msg.content));
	}

public:
	// ErrorSink methods.

	override void onWarning(string msg, string file, int line)
	{
		error.writeln(new "warning: ${msg} (${file}:${line})");
		error.flush();
	}

	override void onWarning(ref in ir.Location loc, string msg, string file, int line)
	{
		uri := getUriFromPath(loc.filename);
		rsp := buildDiagnostic(uri, cast(i32)loc.line-1, cast(i32)loc.column,
			DiagnosticLevel.Warning, msg);
		send(rsp);
	}

	override void onError(string msg, string file, int line)
	{
		error.writeln(new "error: ${msg} (${file}:${line})");
		error.flush();
	}

	override void onError(ref in ir.Location loc, string msg, string file, int line)
	{
		uri := getUriFromPath(loc.filename);
		rsp := buildDiagnostic(uri, cast(i32)loc.line-1, cast(i32)loc.column,
			DiagnosticLevel.Error, msg);
		send(rsp);
	}

	override void onPanic(string msg, string file, int line)
	{
		error.writeln(new "panic: ${msg} (${file}:${line})");
		error.flush();
	}

	override void onPanic(ref in ir.Location loc, string msg, string file, int line)
	{
		uri := getUriFromPath(loc.filename);
		rsp := buildDiagnostic(uri, cast(i32)loc.line-1, cast(i32)loc.column,
			DiagnosticLevel.Error, msg);
		send(rsp);
	}

	fn getModule(uri: string) ir.Module
	{
		mod := parser.parse(uri, this, settings);
		if (mod is null) {
			return null;
		}
		return modules.get(mod.name, uri, this, settings);
	}

private:
	fn handleRO(ro: RequestObject) bool
	{
		switch (ro.methodName) {
		case "initialize":
			send(buildInitialiseResponse(ro.id.integer()));
			return Listening.Continue;
		case "initialized":
			assert(ro.notification);
			return Listening.Continue;
		case "shutdown":
			retval = 0;
			send(buildShutdownResponse(ro.id.integer()));
			return Listening.Continue;
		case "exit":
			return Listening.Stop;
		case "textDocument/didOpen":
		case "textDocument/didChange":
		case "textDocument/didSave":
			uri := documents.handleUpdate(ro);
			parser.fullParse(uri, this, settings);
			return Listening.Continue;
		case "textDocument/documentSymbol":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(buildEmptyResponse(ro.id.integer()));
				return Listening.Continue;
			}
			reply := responseSymbolInformation(this, ro, uri, mod);
			send(reply);
			return Listening.Continue;
		case "textDocument/completion":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(buildEmptyResponse(ro.id.integer()));
				return Listening.Continue;
			}
			reply := responseCompletionInformation(this, ro, uri, mod);
			send(reply);
			return Listening.Continue;
		case "textDocument/signatureHelp":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(buildEmptyResponse(ro.id.integer()));
				return Listening.Continue;
			}
			reply := responseSignatureHelp(this, ro, uri, mod);
			send(reply);
			return Listening.Continue;
		case "textDocument/definition":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(buildEmptyResponse(ro.id.integer()));
				return Listening.Continue;
			}
			reply := responseGotoDefinition(this, ro, uri, mod);
			send(reply);
			return Listening.Continue;
		case "textDocument/hover":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(buildEmptyResponse(ro.id.integer()));
				return Listening.Continue;
			}
			reply := responseHover(this, ro, uri, mod);
			send(reply);
			return Listening.Continue;
		case "workspace/didChangeConfiguration":
			updateConfiguration(ro);
			return Listening.Continue;
		case "workspace/didChangeWatchedFiles":
			updateChangedFiles(ro);
			return Listening.Continue;
		default:
			if (ro.methodName.length > 2 && ro.methodName[0 .. 2] == "$/") {
				/* "If a server or client receives notifications or requests starting
				 *  with '$/' it is free to ignore them if they are unknown."
				 * These are mostly $/cancelRequest -- we're single threaded, so we can't
				 * do anything to that effect.
				 */
				return Listening.Continue;
			}
			// TODO: Return error
			return Listening.Continue;
		}
	}

	fn updateChangedFiles(ro: RequestObject)
	{
		changes := getArrayKey(ro.params, "changes");
		if (changes is null) {
			return;
		}
		foreach (change; changes) {
			if (!change.hasObjectKey("type")) {
				continue;
			}
			type := cast(FileChanged)change.lookupObjectKey("type").integer();
			if (type == FileChanged.Deleted) {
				continue;
			}
			uri := getStringKey(change, "uri");
			path := getPathFromUri(uri);
			if (!exists(path)) {
				continue;
			}
			text := cast(string)read(path);
			documents.set(uri, text);
			parser.fullParse(uri, this, settings);
		}
	}

	fn updateConfiguration(ro: RequestObject)
	{
		if (!ro.params.hasObjectKey("settings")) {
			return;
		}
		settingsKey := ro.params.lookupObjectKey("settings");
		if (!settingsKey.hasObjectKey("volt")) {
			return;
		}
		voltKey := settingsKey.lookupObjectKey("volt");

		pathToVolta = getStringKey(voltKey, "pathToVolta");
		modules.setPackagePath("core", pathToVolta, "rt/src");
		pathToWatt  = getStringKey(voltKey, "pathToWatt");
		modules.setPackagePath("watt", pathToWatt, "src");

		if (voltKey.hasObjectKey("additionalPackagePaths")) {
			vkey := voltKey.lookupObjectKey("additionalPackagePaths");
			if (vkey.type() == json.DomType.Object) {
				keys := vkey.keys();
				foreach (key; keys) {
					ckey := vkey.lookupObjectKey(key);
					if (ckey.type() == json.DomType.String) {
						additionalPaths[key] = ckey.str();
						modules.setPackagePath(key, ckey.str());
					}
				}
			}
		}
	}

	fn handleTextDocument(ro: RequestObject, out uri: string) ir.Module
	{
		err := parseTextDocument(ro.params, out uri);
		if (err !is null) {
			return null;
		}
		return getModule(uri);
	}
}
