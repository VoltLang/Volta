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

import vls = vls.server;

import documents = vls.documents;
import modules   = vls.modules;

fn parse(uri: string, langServer: vls.VoltLanguageServer) ir.Module
{
	source := getSource(uri, langServer);
	tw := getTokenWriter(source);
	mod := getModule(uri, tw, langServer);
	return mod;
}

fn fullParse(uri: string, langServer: vls.VoltLanguageServer) ir.Module
{
	mod := parse(uri, langServer);
	if (mod !is null) {
		lsp.send(lsp.buildNoDiagnostic(uri));
		modules.set(mod.name, mod);
		postparse(uri, mod, langServer);
	}
	return mod;
}

private:

fn getSource(uri: string, langServer: vls.VoltLanguageServer) volta.Source
{
	text := documents.get(uri);
	if (text is null) {
		return null;
	}
	return new volta.Source(text, lsp.getPathFromUri(uri), langServer);
}

fn getTokenWriter(source: volta.Source) volta.TokenWriter
{
	if (source is null) {
		return null;
	}
	tw := volta.lex(source);
	if (tw.lastAdded.type != volta.TokenType.End) {
		// Lexer errors get piped in by the VoltLanguageServer handler.
		return null;
	}
	return tw;
}

fn getModule(uri: string, tw: volta.TokenWriter, langServer: vls.VoltLanguageServer) ir.Module
{
	if (tw is null) {
		return null;
	}
	tokens := tw.getTokens();
	ps := new volta.ParserStream(tokens, langServer.settings, langServer);
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

fn postparse(uri: string, mod: ir.Module, langServer: vls.VoltLanguageServer)
{
	fn modulesGet(qn: ir.QualifiedName) ir.Module
	{
		return modules.get(qn, uri, langServer);
	}
	target     := new volta.TargetInfo();
	pass       := new volta.PostParseImpl(
		err:langServer, vs:langServer.versionSet, target:target,
		warningsEnabled:false, removalOnly:false, doMissing:false,
		getMod:modulesGet
	);
	pass.transform(mod);
}
