module vls.parsing.documentManager;

import watt.io;
import watt.io.streams;
import watt.text.string : replace;
import json = watt.json;

import ir = volta.ir;
import vls.lsp;

import vls.server.responses;
import vls.parsing.postparse;
import vls.server;

import volta.interfaces;
import volta.settings;
import volta.token.source;
import volta.parser.base;
import volta.parser.toplevel;
import volta.token.lexer;

//! Keeps track of the contents of textDocuments.
class DocumentManager
{
public:
	errSink: VoltLanguageServer;
	settings: Settings;

private:
	// Text, keyed with the uri.
	mDocuments: Document[string];

public:
	this(settings: Settings, langServer: VoltLanguageServer)
	{
		this.settings = settings;
		this.errSink = langServer;
	}

public:
	fn update(ro: RequestObject)
	{
		switch (ro.methodName) {
		case "textDocument/didSave":
			updateDidSave(ro.params.lookupObjectKey("textDocument"), ro.params.lookupObjectKey("text").str());
			break;
		case "textDocument/didOpen":
			updateDidOpen(ro.params.lookupObjectKey("textDocument"));
			break;
		case "textDocument/didChange":
			updateDidChange(ro.params.lookupObjectKey("textDocument"), ro.params.lookupObjectKey("contentChanges"));
			break;
		default:
			break;
		}
	}

	fn getText(uri: string) string
	{
		if (ptr := uri in mDocuments) {
			return ptr.content;
		}
		return null;
	}

	fn getModule(uri: string, out mod: ir.Module, out postParse: ir.PostParsePass)
	{
		parse(uri);
		if (ptr := uri in mDocuments) {
			mod = ptr.mod;
			postParse = ptr.postParse;
		}
	}

private:
	fn updateDidSave(val: json.Value, text: string)
	{
		uri := val.lookupObjectKey("uri").str();
		ver := val.lookupObjectKey("version").integer();
		if ((uri in mDocuments) is null) {
			mDocuments[uri] = new Document();
		}
		mDocuments[uri].content = text;
		mDocuments[uri].ver = ver;
		parse(uri);
	}

	fn updateDidOpen(val: json.Value)
	{
		uri := val.lookupObjectKey("uri").str();
		text := val.lookupObjectKey("text").str();
		ver := val.lookupObjectKey("version").integer();
		if ((uri in mDocuments) is null) {
			mDocuments[uri] = new Document();
		}
		mDocuments[uri].content = text;
		mDocuments[uri].ver = ver;
		parse(uri);
	}

	fn updateDidChange(txt: json.Value, changes: json.Value)
	{
		uri := txt.lookupObjectKey("uri").str();
		text := changes.array()[0].lookupObjectKey("text").str();
		ver := txt.lookupObjectKey("version").integer();
		if ((uri in mDocuments) is null) {
			mDocuments[uri] = new Document();
		}
		if (ver < mDocuments[uri].ver) {
			return;
		}
		mDocuments[uri].ver = ver;
		mDocuments[uri].content = text;
	}

	fn parse(uri: string)
	{
		txt := getText(uri);
		src := new Source(txt, getPathFromUri(uri), cast(ErrorSink)errSink);
		mod: ir.Module;
		tw := lex(src);
		if (tw.lastAdded.type != TokenType.End) {
			// Lexer errors get piped in by the ErrorSink handler.
			return;
		}
		ps := new ParserStream(tw.getTokens(), settings, cast(ErrorSink)errSink);
		ps.magicFlagD = tw.magicFlagD;
		ps.get();  // Skip begin
		status := parseModule(ps, out mod);
		if (status != ParseStatus.Succeeded && ps.parserErrors.length >= 1) {
			err := ps.parserErrors[0];
			send(notificationDiagnostic(uri, err.loc, err.errorMessage(), DIAGNOSTIC_ERROR));
			return;
		} else {
			// TODO: This will clobber warnings.
			send(notificationNoDiagnostic(uri));
		}
		postPass := postParse(mod, getPathFromUri(uri), errSink, settings, ref errSink.importCache);
		if ((uri in mDocuments) is null) {
			error.writeln("[internal vls nonsense] uri document went missing?");
			error.flush();
			mDocuments[uri] = new Document();
		}
		mDocuments[uri].mod = mod;
		mDocuments[uri].postParse = postPass;
	}
}

private:

class Document
{
public:
	ver: i64;
	content: string;
	mod: ir.Module;
	postParse: PostParsePass;
}
