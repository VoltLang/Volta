module vls.parser;

import io = watt.io;

import ir = volta.ir;
import volta = [
	volta.interfaces,
	volta.settings,
	volta.token.source,
	volta.token.lexer,
	volta.parser.base,
	volta.parser.toplevel,
	volta.postparse.attribremoval,
	volta.postparse.condremoval,
	volta.postparse.gatherer,
	volta.postparse.importresolver,
	volta.postparse.scopereplacer,
	volta.postparse.pass,
];

import lsp = vls.lsp;

import documents = vls.documents;
import modules   = vls.modules;

fn parse(uri: string, errorSink: volta.ErrorSink, settings: volta.Settings) ir.Module
{
	source := getSource(uri, errorSink);
	tw := getTokenWriter(source);
	mod := getModule(uri, tw, settings, errorSink);
	return mod;
}

fn fullParse(uri: string, errorSink: volta.ErrorSink, settings: volta.Settings) ir.Module
{
	mod := parse(uri, errorSink, settings);
	if (mod !is null) {
		lsp.send(lsp.buildNoDiagnostic(uri));
		modules.set(mod.name, mod);
		postparse(uri, mod, errorSink, settings);
	}
	return mod;
}

private:

fn getSource(uri: string, errorSink: volta.ErrorSink) volta.Source
{
	text := documents.get(uri);
	if (text is null) {
		return null;
	}
	return new volta.Source(text, lsp.getPathFromUri(uri), errorSink);
}

fn getTokenWriter(source: volta.Source) volta.TokenWriter
{
	if (source is null) {
		return null;
	}
	tw := volta.lex(source);
	if (tw.lastAdded.type != volta.TokenType.End) {
		// Lexer errors get piped in by the ErrorSink handler.
		return null;
	}
	return tw;
}

fn getModule(uri: string, tw: volta.TokenWriter, settings: volta.Settings, errorSink: volta.ErrorSink) ir.Module
{
	if (tw is null) {
		return null;
	}
	tokens := tw.getTokens();
	ps := new volta.ParserStream(tokens, settings, errorSink);
	ps.get();  // skip BEGIN
	ps.magicFlagD = tw.magicFlagD;
	mod: ir.Module;
	status := volta.parseModule(ps, out mod);
	if (status == volta.ParseStatus.Succeeded) {
		return mod;
	} else {
		err := ps.parserErrors[0];
		lsp.send(lsp.buildDiagnostic(uri, cast(i32)err.loc.line-1, cast(i32)err.loc.column,
				lsp.DiagnosticLevel.Error, err.errorMessage()));
		return null;
	}
}

fn postparse(uri: string, mod: ir.Module, errorSink: volta.ErrorSink, settings: volta.Settings)
{
	fn modulesGet(qn: ir.QualifiedName) ir.Module { return modules.get(qn, uri, errorSink, settings); }
	versionSet := new volta.VersionSet();
	target     := new volta.TargetInfo();
	pass       := new volta.PostParseImpl(
		err:errorSink, vs:versionSet, target:target,
		warningsEnabled:false, removalOnly:false, doMissing:false,
		getMod:modulesGet
	);
	pass.transform(mod);
}
