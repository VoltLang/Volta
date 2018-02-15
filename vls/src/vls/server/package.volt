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
import vls.parsing.postparse;
import vls.parsing.documentManager;
import vls.util.simpleCache;
import vls.semantic.symbolGathererVisitor;
import build = vls.build;

class VoltLanguageServer : ErrorSink
{
public:
	//! Used for testing external modules, unused in usual operation.
	modulePath: string;
	settings: Settings;
	documentManager: DocumentManager;
	importCache: SimpleImportCache;
	sgv: SymbolGathererVisitor;

	buildManager: build.Manager;
	pendingBuild: build.Build;

	retval: i32;

	pathToVolta: string;
	pathToWatt: string;
	additionalPaths: string[string];

public:
	this(argZero: string, modulePath: string)
	{
		execDir := getExecDir();

		buildManager = new build.Manager(execDir);

		this.modulePath = modulePath;
		settings = new Settings(argZero, execDir);
		settings.warningsEnabled = true;
		documentManager = new DocumentManager(settings, this);
		sgv = new SymbolGathererVisitor();
	}

	/// LSP listen callback.
	fn handle(msg: LspMessage) bool
	{
		return handleRO(new RequestObject(msg.content));
	}

	fn cleanup()
	{
		buildManager.cleanup();
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
		send(notificationDiagnostic(getUriFromPath(loc.filename), loc, msg, DIAGNOSTIC_WARNING));
	}

	override void onError(string msg, string file, int line)
	{
		error.writeln(new "error: ${msg} (${file}:${line})");
		error.flush();
	}

	override void onError(ref in ir.Location loc, string msg, string file, int line)
	{
		send(notificationDiagnostic(getUriFromPath(loc.filename), loc, msg, DIAGNOSTIC_ERROR));
	}

	override void onPanic(string msg, string file, int line)
	{
		error.writeln(new "panic: ${msg} (${file}:${line})");
		error.flush();
	}

	override void onPanic(ref in ir.Location loc, string msg, string file, int line)
	{
		send(notificationDiagnostic(getUriFromPath(loc.filename), loc, msg, DIAGNOSTIC_ERROR));
	}

private:
	fn handleRO(ro: RequestObject) bool
	{
		switch (ro.methodName) {
		case "initialize":
			send(responseInitialized(ro));
			return CONTINUE_LISTENING;
		case "initialized":
			assert(ro.notification);
			return CONTINUE_LISTENING;
		case "shutdown":
			retval = 0;
			send(responseShutdown(ro));
			return CONTINUE_LISTENING;
		case "exit":
			return STOP_LISTENING;
		case "textDocument/didOpen":
		case "textDocument/didChange":
		case "textDocument/didSave":
			documentManager.update(ro);
			return CONTINUE_LISTENING;
		case "textDocument/documentSymbol":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(responseNull(ro));
				return CONTINUE_LISTENING;
			}
			reply := responseSymbolInformation(this, ro, uri, mod);
			send(reply);
			return CONTINUE_LISTENING;
		case "textDocument/completion":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(responseNull(ro));
				return CONTINUE_LISTENING;
			}
			reply := responseCompletionInformation(this, ro, uri, mod);
			send(reply);
			return CONTINUE_LISTENING;
		case "textDocument/signatureHelp":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(responseNull(ro));
				return CONTINUE_LISTENING;
			}
			reply := responseSignatureHelp(this, ro, uri, mod);
			send(reply);
			return CONTINUE_LISTENING;
		case "textDocument/definition":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(responseNull(ro));
				return CONTINUE_LISTENING;
			}
			reply := responseGotoDefinition(this, ro, uri, mod);
			send(reply);
			return CONTINUE_LISTENING;
		case "textDocument/hover":
			uri: string;
			mod := handleTextDocument(ro, out uri);
			if (mod is null) {
				send(responseNull(ro));
				return CONTINUE_LISTENING;
			}
			reply := responseHover(this, ro, uri, mod);
			send(reply);
			return CONTINUE_LISTENING;
		case "workspace/didChangeConfiguration":
			updateConfiguration(ro);
			return CONTINUE_LISTENING;
		case "workspace/executeCommand":
			handleCommand(ro);
			return CONTINUE_LISTENING;
		default:
			if (ro.methodName.length > 2 && ro.methodName[0 .. 2] == "$/") {
				/* "If a server or client receives notifications or requests starting
				 *  with '$/' it is free to ignore them if they are unknown."
				 * These are mostly $/cancelRequest -- we're single threaded, so we can't
				 * do anything to that effect.
				 */
				return CONTINUE_LISTENING;
			}
			// TODO: Return error
			return CONTINUE_LISTENING;
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
		pathToWatt  = getStringKey(voltKey, "pathToWatt");

		if (voltKey.hasObjectKey("additionalPackagePaths")) {
			vkey := voltKey.lookupObjectKey("additionalPackagePaths");
			if (vkey.type() == json.DomType.OBJECT) {
				keys := vkey.keys();
				foreach (key; keys) {
					ckey := vkey.lookupObjectKey(key);
					if (ckey.type() == json.DomType.STRING) {
						additionalPaths[key] = ckey.str();
					}
				}
			}
		}
	}

	fn handleCommand(ro: RequestObject)
	{
		command := getStringKey(ro.params, "command");
		if (command is null) {
//			send(responseError(ro, "expected 'command' string field"));
			return;
		}
		switch (command) {
		case "vls.buildProject":
			buildProject(ro);
			break;
		default:
//			send(responseError(ro, new "unknown command '${command}'"));
			break;
		}
	}

	fn handleTextDocument(ro: RequestObject, out uri: string) ir.Module
	{
		err := parseTextDocument(ro.params, out uri);
		if (err !is null) {
//			send(responseError(ro, err));
			return null;
		}
		mod: ir.Module;
		postParse: PostParsePass;
		documentManager.getModule(uri, out mod, out postParse);
		return mod;
	}

private:
	// Commands.

	fn buildProject(ro: RequestObject)
	{
		arguments := getArrayKey(ro.params, "arguments");
		if (arguments.length == 0) {
			return;
		}
		if (arguments[0].type() != json.DomType.OBJECT) {
			return;
		}
		fspath := getStringKey(arguments[0], "fsPath");
		btoml := getBatteryToml(fspath);
		if (btoml is null) {
			return;
		}
		pendingBuild = buildManager.spawnBuild(btoml);
	}

private:
	// Helper JSON functions.

	fn validateKey(root: json.Value, field: string, t: json.DomType, ref val: json.Value) bool
	{
		if (root.type() != json.DomType.OBJECT ||
			!root.hasObjectKey(field)) {
			return false;
		}
		val = root.lookupObjectKey(field);
		if (val.type() != t) {
			return false;
		}
		return true;
	}

	fn getStringKey(root: json.Value, field: string) string
	{
		val: json.Value;
		retval := validateKey(root, field, json.DomType.STRING, ref val);
		if (!retval) {
			return null;
		}
		return val.str();
	}

	fn getArrayKey(root: json.Value, field: string) json.Value[]
	{
		val: json.Value;
		retval := validateKey(root, field, json.DomType.ARRAY, ref val);
		if (!retval) {
			return null;
		}
		return val.array();
	}
}
