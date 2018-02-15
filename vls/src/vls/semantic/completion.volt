module vls.semantic.completion;

import core = core.rt.format;
import watt = [watt.text.string, watt.io, watt.conv, watt.path, watt.json.util, watt.text.ascii, watt.text.sink];

import ir = [volta.ir, volta.ir.location];
import parser = [volta.parser.base, volta.parser.expression];
import visitor = [volta.visitor.visitor, volta.visitor.scopemanager];
import lsp = vls.lsp;
import server = [vls.parsing.documentManager, vls.server.responses, vls.semantic.scopeFinder,
	vls.util.simpleCache, vls.parsing.docParser, vls.semantic.lookup, vls.server, vls.util.printing,
	vls.semantic.symbolGathererVisitor];
import semantic = [vls.semantic.completionList, vls.semantic.actualiseClass];
import volta = [volta.interfaces, volta.settings, volta.token.lexer, volta.token.source];
import printer = volta.ir.printer;

//! Response for `textDocument/completion`.
fn getCompletionResponse(ro: lsp.RequestObject, uri: string, theServer: server.VoltLanguageServer) string
{
	fn failedToFind() string
	{
		return server.responseNull(ro);
	}

	mod: ir.Module;
	postParse: volta.PostParsePass;
	theServer.documentManager.getModule(uri, out mod, out postParse);
	if (mod is null) {
		return failedToFind();
	}

	loc := getLocationFromRequestObject(ro);
	theLine := getLineAtLocation(theServer.documentManager, uri, ref loc);
	if (theLine.length == 0) {
		return failedToFind();
	}

	completionItems := getCompletionItems(theServer, mod, postParse, ref loc, theLine);
	if (completionItems.length == 0) {
		return failedToFind();
	}
	ss: watt.StringSink;
	ss.sink(`{"jsonrcp":"2.0","id":`);
	core.vrt_format_i64(ss.sink, ro.id.integer());
	ss.sink(`, "result":`);
	ss.sink(completionItems);
	ss.sink(`}`);
	return ss.toString();
}

//! Response for `textDocument/hover`.
fn getHoverResponse(ro: lsp.RequestObject, uri: string, theServer: server.VoltLanguageServer) string
{
	fn failedToFind() string
	{
		return server.responseNull(ro);
	}

	mod: ir.Module;
	postParse: volta.PostParsePass;
	theServer.documentManager.getModule(uri, out mod, out postParse);
	if (mod is null) {
		return failedToFind();
	}

	loc := getLocationFromRequestObject(ro);
	theLine := getLineAtLocation(theServer.documentManager, uri, ref loc);
	theWord := getWordAtLocation(theServer.documentManager, theLine, ref loc);

	parentScope := server.findScope(ref loc, mod, postParse, theServer);
	if (parentScope is null) {
		return failedToFind();
	}

	exp := parseFragmentExpression(theWord, theServer.settings, theServer);
	if (exp is null) {
		return failedToFind();
	}

	oneTimeCache: server.SimpleImportCache;
	store := server.getStoreFromFragment(ref oneTimeCache, exp, mod.myScope, parentScope);
	if (store is null) {
		return failedToFind();
	}

	asFunction := store.node.toFunctionChecked();
	if (asFunction is null) {
		return failedToFind();
	}

	str := asFunction.docComment;
	if (watt.strip(str) == "") {
		str = asFunction.loc.toString();
		str = new "```volt\n${server.functionString(asFunction)}\n```";
	}

	ss: watt.StringSink;
	ss.sink(`{"jsonrcp":"2.0","id":`);
	core.vrt_format_i64(ss.sink, ro.id.integer());
	ss.sink(`,"result":{"contents":{"kind":"markdown","value":"`);
	ss.sink(watt.escapeString(str));
	ss.sink(`"}}}`);
	return ss.toString();
}

//! Response for `textDocument/signatureHelp`
fn getSignatureHelpResponse(ro: lsp.RequestObject, uri: string, theServer: server.VoltLanguageServer) string
{
	fn failedToFind() string
	{
		return server.responseNull(ro);
	}

	mod: ir.Module;
	postParse: volta.PostParsePass;
	theServer.documentManager.getModule(uri, out mod, out postParse);
	if (mod is null) {
		return failedToFind();
	}

	loc := getLocationFromRequestObject(ro);
	theLine := watt.strip(getLineAtLocation(theServer.documentManager, uri, ref loc));

	if (theLine.length > 0 && theLine[$-1] == ')') {
		theLine = theLine[0 .. $-1];
	}
	commas: size_t;
	while (theLine.length > 0 && theLine[$-1] != '(') {
		if (theLine[$-1] == ',') {
			commas++;  // TODO: Commas in string literals, array literals, etc.
		}
		theLine = theLine[0 .. $-1];
	}
	if (theLine.length > 0 && theLine[$-1] == '(') {
		theLine = theLine[0 .. $-1];
	}
	if (theLine.length == 0) {
		return failedToFind();
	}

	parentScope := server.findScope(ref loc, mod, postParse, theServer);
	if (parentScope is null) {
		return failedToFind();
	}

	exp := parseFragmentExpression(theLine, theServer.settings, theServer);
	if (exp is null) {
		return failedToFind();
	}

	oneTimeCache: server.SimpleImportCache;
	store := server.getStoreFromFragment(ref oneTimeCache, exp, mod.myScope, parentScope);
	if (store is null) {
		return failedToFind();
	}

	asFunction := store.node.toFunctionChecked();
	if (asFunction is null || commas >= asFunction.params.length) {
		return failedToFind();
	}

	ss: watt.StringSink;
	ss.sink(`{"jsonrcp":"2.0","id":`);
	core.vrt_format_i64(ss.sink, ro.id.integer());
	ss.sink(`,"result":{"signatures":[{"label":"`);
	ss.sink(server.functionString(asFunction));
	ss.sink(`","parameters":[`);
	foreach (i, param; asFunction.params) {
		ss.sink(`{"label":"`);
		ss.sink(param.name);
		ss.sink(`: `);
		ss.sink(printer.printType(param.type));
		ss.sink(`","documentation":{"kind":"markdown","value": "`);
		ss.sink(server.getFunctionParamDoc(asFunction, i));
		ss.sink(`"}}`);
		if (i < asFunction.params.length - 1) {
			ss.sink(`,`);
		}
	}
	ss.sink(`]}],"activeSignature":0,"activeParameter":`);
	core.vrt_format_u64(ss.sink, commas);
	ss.sink(`}}`);
	return ss.toString();
}


//! Response for `textDocument/definition`
fn getGotoDefinitionResponse(ro: lsp.RequestObject, uri: string, theServer: server.VoltLanguageServer) string
{
	fn failedToFind() string
	{
		return server.responseNull(ro);
	}

	mod: ir.Module;
	postParse: volta.PostParsePass;
	theServer.documentManager.getModule(uri, out mod, out postParse);
	if (mod is null) {
		return failedToFind();
	}

	loc := getLocationFromRequestObject(ro);
	theLine := getLineAtLocation(theServer.documentManager, uri, ref loc);
	theWord := getWordAtLocation(theServer.documentManager, theLine, ref loc);

	parentScope := server.findScope(ref loc, mod, postParse, theServer);
	if (parentScope is null) {
		return failedToFind();
	}

	oneTimeCache: server.SimpleImportCache;
	endOfLineLocation: ir.Location;
	endOfLineLocation.line = loc.line;
	endOfLineLocation.column = cast(u32)(theLine.length - 1);

	getLookupWordAndScope(oneTimeCache, ref theWord, ref parentScope);
	if (parentScope is null) {
		return failedToFind();
	}

	store := server.lookup(ref oneTimeCache, parentScope, theWord);
	if (store is null) {
		return failedToFind();
	}

	ss: watt.StringSink;
	ss.sink(`{"jsonrcp":"2.0","id":`);
	core.vrt_format_i64(ss.sink, ro.id.integer());
	ss.sink(`,"result":{"uri":"`);
	ss.sink(lsp.getUriFromPath(store.node.loc.filename));
	ss.sink(`","range":`);
	server.locationToRange(ref store.node.loc, ss.sink);
	ss.sink(`}}`);
	return ss.toString();
}

private:

fn parseFragmentExpression(fragment: string, settings: volta.Settings, errSink: volta.ErrorSink) ir.Exp
{
	src := new volta.Source(fragment, "", errSink);
	ps  := new parser.ParserStream(volta.lex(src).getTokens(), settings, errSink);
	ps.get();  // Skip BEGIN token.
	exp: ir.Exp;
	status := parser.parseExp(ps, out exp);
	if (status != parser.ParseStatus.Succeeded) {
		return null;
	}
	return exp;
}

fn getCompletionItems(theServer: server.VoltLanguageServer, parentModule: ir.Module, postParse: volta.PostParsePass, ref loc: ir.Location, theLine: string) string
{
	/* Field completion items are items that are looked up in a parent item,
	 * via the '.' operator.
	 * Name completion items are just names looked up in a given context.
	 * Such as by typing an identifier and waiting, or hitting ctrl+space.
	 */
	if (theLine[$-1] == '.') {
		return getFieldCompletionItems(theServer, parentModule, postParse, ref loc, theLine);
	} else {
		return getNameCompletionItems(theServer,parentModule, postParse, ref loc, theLine);
	}
}

fn getNameCompletionItems(theServer: server.VoltLanguageServer, parentModule: ir.Module, postParse: volta.PostParsePass,
	ref loc: ir.Location, theLine: string) string
{
	beginning := watt.strip(theLine);
	completionList: semantic.CompletionList;
	getSymbolsThatStartWith(ref loc, parentModule, beginning, theServer, postParse, ref completionList);
	return completionList.jsonArray();
}

fn getSymbolsThatStartWith(ref loc: ir.Location, mod: ir.Module, beginning: string, theServer: server.VoltLanguageServer,
	postParse: volta.PostParsePass, ref completionList: semantic.CompletionList, depth: i32 = 0)
{
	if (depth == 0) {
		parentScope := server.findScope(ref loc, mod, postParse, theServer);
		while (parentScope !is null) {
			foreach (name, store; parentScope.symbols) {
				if (watt.startsWith(name, beginning)) {
					completionList.add(name, store);
				}
			}
			parentScope = parentScope.parent;
		}
	}

	foreach (name, store; mod.myScope.symbols) {
		if (watt.startsWith(name, beginning)) {
			access := getAccess(store);
			if (depth == 0 || access == ir.Access.Public) {
				completionList.add(name, store);
			}
		}
	}
	// TODO: Public imports etc
	if (depth == 0) {
		foreach (importedMod; mod.myScope.importedModules) {
			getSymbolsThatStartWith(ref loc, importedMod, beginning, theServer, postParse, ref completionList, depth + 1);
		}
	}
}

//! For the input line, at the given location in the given module, return an array of `CompletionItem`.
fn getFieldCompletionItems(theServer: server.VoltLanguageServer, parentModule: ir.Module, postParse: volta.PostParsePass, ref loc: ir.Location, theLine: string) string
{
	oneTimeCache: server.SimpleImportCache;
	theLine = theLine[0 .. $-1];  // Shave '.'
	endOfLineLocation: ir.Location;
	endOfLineLocation.line = loc.line;
	endOfLineLocation.column = cast(u32)(theLine.length - 1);
	childWord := getWordAtLocation(theServer.documentManager, theLine, ref endOfLineLocation);
	parentScope := server.findScope(ref loc, parentModule, postParse, theServer);
	if (parentScope is null) {
		return null;
	}
	getLookupWordAndScope(oneTimeCache, ref childWord, ref parentScope);
	if (parentScope is null) {
		return null;
	}
	store := server.lookup(ref oneTimeCache, parentScope, childWord);
	if (store is null) {
		return null;
	}

	completionList: semantic.CompletionList;
	if (isBuiltin(ref completionList, ref oneTimeCache, store, parentScope)) {
		return completionList.jsonArray();
	}

	_scope := server.getScopeFromStore(ref oneTimeCache, store, parentScope);
	if (_scope is null) {
		return null;
	}

	completionList.add(_scope);
	foreach (mscope; _scope.multibindScopes) {
		completionList.add(mscope);
	}

	if (_scope.node !is null) {
		asClass := _scope.node.toClassChecked();
		if (asClass !is null) {
			semantic.actualise(ref oneTimeCache, asClass);
			asClass = asClass.parentClass;
			while (asClass !is null) {
				completionList.add(asClass.myScope);
				asClass = asClass.parentClass;
			}
		}
	}

	completionList.exclude(lsp.COMPLETION_MODULE);
	return completionList.jsonArray();
}

fn getAccess(store: ir.Store) ir.Access
{
	switch (store.node.nodeType) with (ir.NodeType) {
	case Variable:
		var := store.node.toVariableFast();
		return var.access;
	case Alias:
		ali := store.node.toAliasFast();
		return ali.access;
	case Function:
		fun := store.node.toFunctionFast();
		return fun.access;
	case EnumDeclaration:
		edc := store.node.toEnumDeclarationFast();
		return edc.access;
	default:
		return ir.Access.Public;
	}
}

//! Given a `textDocument/completion` request object, return an IR `Location`.
fn getLocationFromRequestObject(ro: lsp.RequestObject) ir.Location
{
	position := ro.params.lookupObjectKey("position");
	lineNumber := cast(size_t)position.lookupObjectKey("line").integer();
	columnNumber := cast(size_t)position.lookupObjectKey("character").integer();
	loc: ir.Location;
	loc.line = cast(u32)(lineNumber + 1);
	loc.column = cast(u32)(columnNumber + 1);
	return loc;
}

//! Get the line from the file pointed to by `uri`'s current text at the line pointed to by `loc`.
fn getLineAtLocation(documentManager: server.DocumentManager, uri: string, ref loc: ir.Location) string
{
	src := documentManager.getText(uri);
	lines := watt.splitLines(src);
	theLine: string;
	foreach (i, line; lines) {
		if (i == loc.line - 1) {
			theLine = line;
		}
	}
	return theLine;
}

fn getWordAtLocation(documentManager: server.DocumentManager, line: string, ref loc: ir.Location) string
{
	if (loc.column >= line.length) {
		return "";
	}

	fn okay(c: dchar) bool
	{
		return c == '.' || c == '_' || watt.isAlphaNum(c);
	}

	lowerIndex: size_t = loc.column;
	while (lowerIndex > 0 && okay(line[lowerIndex])) {
		lowerIndex--;
	}
	lowerIndex++;

	upperIndex: size_t = loc.column;
	while (upperIndex < line.length && okay(line[upperIndex])) {
		upperIndex++;
	}

	if (lowerIndex >= upperIndex || lowerIndex >= line.length || upperIndex > line.length) {
		return "";
	}

	return line[lowerIndex .. upperIndex];
}

// *** This should probably be handled by a visitor.
//! If `node` is a statement containing a `BlockStatement`, return true.
fn getBlockStatement(node: ir.Node, ref bs: ir.BlockStatement) bool
{
	switch (node.nodeType) with (ir.NodeType) {
	case BlockStatement:
		bs = node.toBlockStatementFast();
		return true;
	case IfStatement:
		ifs := node.toIfStatementFast();
		bs = ifs.thenState;
		return true;
	case WhileStatement:
		ws := node.toWhileStatementFast();
		bs = ws.block;
		return true;
	case DoStatement:
		ds := node.toDoStatementFast();
		bs = ds.block;
		return true;
	case ForStatement:
		fs := node.toForStatementFast();
		bs = fs.block;
		return true;
	case ForeachStatement:
		fes := node.toForeachStatementFast();
		bs = fes.block;
		return true;
	case SwitchCase:
		sc := node.toSwitchCaseFast();
		bs = sc.statements;
		return true;
	case WithStatement:
		ws := node.toWithStatementFast();
		bs = ws.block;
		return true;
	case SynchronizedStatement:
		ss := node.toSynchronizedStatementFast();
		bs = ss.block;
		return true;
	case ScopeStatement:
		ss := node.toScopeStatementFast();
		bs = ss.block;
		return true;
	case PragmaStatement:
		ps := node.toPragmaStatementFast();
		bs = ps.block;
		return true;
	default:
		return false;
	}
}

/*!
 * Get a scope and word to lookup in it, from a lookup string.
 *
 * That is, given a `lookupString` of `_struct.subStruct.field`, return
 * the scope for `_struct.subStruct` and the word `field`.
 *
 * If there are no '.' in `lookupString`, then the parameters are
 * unchanged. If there is one or more '.', but the scope and word
 * cannot be determined for some reason, then parentScope will be null.
 * Otherwise, `lookupString` will be the leaf word, and `parentScope`
 * will be the scope to look it up in.
 *
 * @Param cache The cache to use when doing lookups.
 * @Param lookupString The string to split apart, if needed.
 * @Param parentScope The scope to start lookup in.
 */
fn getLookupWordAndScope(cache: server.SimpleImportCache, ref lookupString: string, ref parentScope: ir.Scope)
{
	if (watt.indexOf(lookupString, '.') > 0) {
		parts := watt.split(lookupString, '.');
		lookupString = parts[$-1];
		foreach (part; parts[0 .. $-1]) {
			store := server.lookup(ref cache, parentScope, part);
			if (store is null) {
				parentScope = null;
				return;
			}
			_scope := server.getScopeFromStore(ref cache, store, parentScope);
			if (_scope is null) {
				parentScope = null;
				return;
			}
			parentScope = _scope;
		}
	}
}

fn isBuiltin(ref completionList: semantic.CompletionList, ref cache: server.SimpleImportCache, store: ir.Store, context: ir.Scope) bool
{
	vtype: ir.Node = server.getTypeFromVariableLike(ref cache, store, context);
	if (vtype is null) {
		return false;
	}
	tr := vtype.toTypeReferenceChecked();
	if (tr !is null) {
		copyCache := cache;  // Don't mark modules as looked up with this.
		tlstore := server.lookup(ref copyCache, context, tr.id);
		if (tlstore is null) {
			return false;
		}
		vtype = tlstore.node;
	}
	vtype = server.resolveAlias(vtype, ref cache, context);
	if (vtype is null) {
		return false;
	}
	switch (vtype.nodeType) with (ir.NodeType) {
	case ArrayType:
		array := vtype.toArrayTypeFast();
		lengthDoc := semantic.getDocumentationTitle(ref store.node.loc, "length: size_t");
		completionList.add("length", lsp.COMPLETION_FIELD, lengthDoc);
		ss: watt.StringSink;
		ss.sink("ptr: ");
		ss.sink(printer.printType(array.base));
		ss.sink("*");
		ptrDoc := semantic.getDocumentationTitle(ref store.node.loc, ss.toString());
		completionList.add("ptr", lsp.COMPLETION_FIELD, ptrDoc);
		return true;
	default:
		return false;
	}
}
