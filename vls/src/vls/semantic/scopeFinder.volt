module vls.semantic.scopeFinder;

import watt = watt.io;
import volta = [volta.interfaces, volta.parser.parser, volta.util.stack];
import server = vls.server;
import ir = [volta.ir, volta.ir.location];
import visitor = volta.visitor;

/*!
 * Convenience function that uses `ScopeFinder` to find a scope.
 */
fn findScope(ref targetLocation: ir.Location, mod: ir.Module, postPass: volta.PostParsePass, langServer: server.VoltLanguageServer) ir.Scope
{
	scopeFinder := new ScopeFinder(ref targetLocation, postPass, langServer);
	visitor.accept(mod, scopeFinder);
	return scopeFinder.foundScope;
}

/*!
 * Given a `Location`, find a `Scope` that that `Location` would fall in.
 */
class ScopeFinder : visitor.NullVisitor
{
public:
	/*!
	 * The `Location` that this `ScopeFinder` searches for.
	 *
	 * The filename is ignored; the `Module` given to `accept` is
	 * assumed to be the correct one for this `Location`.
	 */
	targetLocation: ir.Location;

	/*!
	 * The `Scope` that was found.
	 *
	 * This is filled in once you call `accept` on the `Module` you
	 * are searching. This can be null.
	 */
	foundScope: ir.Scope;

	/*!
	 * The function that `foundScope` was found in, if any.
	 */
	foundFunction: ir.Function;

	/*!
	 * The aggregate that `foundScope` was found in, if any.
	 */
	foundAggregate: ir.Aggregate;

private:
	mScope: ir.Scope;
	mNode: ir.Node;
	mFunctionStack: volta.FunctionStack;
	mAggregateStack: volta.AggregateStack;
	mPostParse: volta.PostParsePass;
	mServer: server.VoltLanguageServer;

public:
	/*!
	 * Construct a new `ScopeFinder`.
	 *
	 * @Param targetLocation The `Location` to search for a `Scope` to match.
	 */
	this(ref targetLocation: ir.Location, postPass: volta.PostParsePass, langServer: server.VoltLanguageServer)
	{
		this.targetLocation = targetLocation;
		this.mPostParse = postPass;
		this.mServer = langServer;
	}

protected:
	fn checkLocation(node: ir.Node, checkedScope: ir.Scope) Status
	{
		if (node.loc.line > targetLocation.line) {
			return Stop;
		}
		foundScope = checkedScope;
		if (mFunctionStack.length > 0) {
			foundFunction = mFunctionStack.peek();
		}
		if (mAggregateStack.length > 0) {
			foundAggregate = mAggregateStack.peek();
		}
		return Continue;
	}

public override:
	fn enter(b: ir.BlockStatement) Status
	{
		return checkLocation(b, b.myScope);
	}

	fn enter(func: ir.Function) Status
	{
		if (!func.hasBody) {
			return Continue;
		}
		if (func.parsedBody is null) {
			if (targetLocation.line < func.tokensBody[0].loc.line ||
				targetLocation.line > func.tokensBody[$-1].loc.line) {
				return Continue;
			}
			tokens := func.tokensBody;
			/* So if the user has
			 *     s.
			 *     foo("blah");
			 * We know the line they're looking at, so remove that line.
			 * This is crude. The real solution is likely adding a vls
			 * only lexing mode that leaves in whitespace, and adding
			 * a bunch of "incomplete parse" nodes for 's.' and 'foo(blah'
			 * etc.
			 */
			removeLine(ref tokens, targetLocation.line);
			p := new volta.Parser(mServer.settings, mServer);
			func.parsedBody = p.parseBlockStatement(ref tokens);
			mPostParse.transformChildBlocks(func);
		}
		mFunctionStack.push(func);
		return Continue;
	}

	fn leave(func: ir.Function) Status
	{
		if (mFunctionStack.length == 0 || mFunctionStack.peek() !is func) {
			return Continue;
		}
		mFunctionStack.pop();
		return Continue;
	}

	fn enter(clazz: ir.Class) Status
	{
		mAggregateStack.push(cast(ir.Aggregate)cast(void*)clazz);
		return Continue;
	}

	fn leave(clazz: ir.Class) Status
	{
		mAggregateStack.pop();
		return Continue;
	}

	fn enter(struc: ir.Struct) Status
	{
		mAggregateStack.push(cast(ir.Aggregate)cast(void*)struc);
		return Continue;
	}

	fn leave(struc: ir.Struct) Status
	{
		mAggregateStack.pop();
		return Continue;
	}
}

private:

fn removeLine(ref tokens: ir.Token[], line: size_t)
{
	if (line < tokens[0].loc.line || line > tokens[$-1].loc.line || line == 0) {
		return;
	}
	outTokens := new ir.Token[](tokens.length);
	i: size_t;
	foreach (token; tokens) {
		if (token.loc.line != line) {
			outTokens[i++] = token;
		}
	}
	tokens = outTokens[0 .. i];
}
