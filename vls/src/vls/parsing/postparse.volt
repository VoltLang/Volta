module vls.parsing.postparse;

import watt = [watt.text.string, watt.path, watt.io.file, watt.text.path, watt.io];

import volta.interfaces;
import ir = volta.ir;

import volta.settings;
import volta.token.source;
import volta.parser.base;
import volta.parser.toplevel;
import volta.token.lexer;

import volta.postparse.attribremoval;
import volta.postparse.condremoval;
import volta.postparse.gatherer;
import volta.postparse.importresolver;
import volta.postparse.scopereplacer;
import volta.postparse.pass;

import vls.lsp.util;
import vls.server;
import vls.util.simpleCache;

fn postParse(mod: ir.Module, base: string, langServer: VoltLanguageServer, settings: Settings, ref cache: SimpleImportCache) PostParsePass
{
	fn getModule(qname: ir.QualifiedName) ir.Module
	{
		extension := "volt";
		path := base;
		identifiers := qname.identifiers;
		if (identifiers[0].value == "watt" || identifiers[0].value == "core" || identifiers[0].value == "volta" ||
			identifiers[0].value == "vls" || identifiers[0].value == "volt") {
			if (identifiers.length < 2) {
				return null;
			}
			if (identifiers[0].value == "watt") {
				switch (identifiers[1].value) {
				case "http":
					path = watt.concatenatePath(langServer.pathToWatt, "http/src/watt");
					break;
				case "json":
					path = watt.concatenatePath(langServer.pathToWatt, "json/src/watt");
					break;
				case "markdown":
					path = watt.concatenatePath(langServer.pathToWatt, "markdown/src/watt");
					break;
				case "toml":
					path = watt.concatenatePath(langServer.pathToWatt, "toml/src/watt");
					break;
				default:
					path = watt.concatenatePath(langServer.pathToWatt, "src/watt");
					break;
				}
			} else {
				switch (identifiers[0].value) {
				case "volt":
					path = watt.concatenatePath(langServer.pathToVolta, "src/volt");
					extension = "d";
					break;
				case "volta":
					path = watt.concatenatePath(langServer.pathToVolta, "lib/src/volta");
					extension = "d";
					break;
				case "vls":
					path = watt.concatenatePath(langServer.pathToVolta, "vls/src/vls");
					break;
				default:
					path = watt.concatenatePath(langServer.pathToVolta, "rt/src/core");
					break;
				}
			}
			if (path.length == 0) {
				return null;
			}
			identifiers = identifiers[1 .. $];
		} else if (langServer.modulePath !is null) {
			path = langServer.modulePath;
		} else if (p := identifiers[0].value in langServer.additionalPaths) {
			path = *p;
		} else {
			path = watt.dirName(path);
			version (Windows) path = watt.replace(path, "\\", "/");
			srci := watt.indexOf(path, "src/");
			if (srci > 0) {
				path = path[0 .. srci+4/*'src/'*/];
			}
		}
		foreach (ident; identifiers[0 .. $-1]) {
			path = watt.concatenatePath(path, ident.value);
		}

		packagePath := watt.concatenatePath(path, identifiers[$-1].value);
		packagePath = watt.concatenatePath(packagePath, new "package.${extension}");
		if (watt.exists(packagePath)) {
			path = packagePath;
		} else {
			fname := new "${identifiers[$-1].value}.${extension}";
			path = watt.concatenatePath(path, fname);
		}
		if (cache.hasResult(path)) {
			return cache.getResult(path);
		}
		parsedModule := parseFromPath(path, langServer, settings);
		if (parsedModule is null) {
			cache.setResult(path, parsedModule);
			return null;
		}
		cache.setResult(path, parsedModule);
		postParse(parsedModule, base, langServer, settings, ref cache);
		return parsedModule;
	}
	ver := new VersionSet();
	target := new TargetInfo();
	pass := new PostParseImpl(err:langServer, vs:ver, target:target,
		warningsEnabled:false, removalOnly:false, doMissing:false, getMod:getModule);
	pass.transform(mod);
	return pass;
}

fn parseFromPath(path: string, errSink: ErrorSink, settings: Settings) ir.Module
{
	if (!watt.exists(path)) {
		watt.error.writeln(new "Tried to parse '${path}'...");
		watt.error.flush();
		return null;
	}
	txt := cast(string)watt.read(path);
	src := new Source(txt, path, errSink);
	mod: ir.Module;
	tw := lex(src);
	if (tw.lastAdded.type != TokenType.End) {
		// TODO: Lexer errors, unify this parsing code with docman
		return null;
	}
	ps := new ParserStream(tw.getTokens(), settings, errSink);
	ps.magicFlagD = tw.magicFlagD;
	ps.get();  // Skip begin
	status := parseModule(ps, out mod);
	if (status != ParseStatus.Succeeded && ps.parserErrors.length >= 1) {
		e := ps.parserErrors[0];
		errSink.onError(ref e.loc, e.errorMessage(), e.raiseFile, e.raiseLine);
		return null;
	}
	return mod;
}
