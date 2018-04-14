/*#D*/
// Copyright 2012-2017, Bernard Helyer.
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.postparse.pass;

import io = watt.io.std;

import ir = volta.ir;
import vi = volta.visitor;

import volta.errors;
import volta.interfaces;

import volta.util.sinks;
import volta.util.moduleFromScope;

import volta.postparse.missing : MissingDeps;
import volta.postparse.gatherer;
import volta.postparse.condremoval;
import volta.postparse.attribremoval;
import volta.postparse.scopereplacer;
import volta.postparse.importresolver;


class PostParseImpl : vi.NullVisitor, PostParsePass
{
public:
	MissingDeps missing;


protected:
	ErrorSink mErr;
	ConditionalRemoval mCond;

	Pass[] mPasses;

	ScopeReplacer mScope;
	AttribRemoval mAttrib;
	Gatherer mGatherer;


public:
	this(ErrorSink err, VersionSet vs, TargetInfo target, bool warningsEnabled, bool removalOnly, bool doMissing, GetMod getMod)
	{
		mErr = err;
		mCond = new ConditionalRemoval(err, vs);

		if (removalOnly) {
			return;
		}

		mPasses ~= mScope = new ScopeReplacer(err);
		mPasses ~= mAttrib = new AttribRemoval(target, err);
		mPasses ~= mGatherer = new Gatherer(warningsEnabled, err);
		if (doMissing) {
			missing = new MissingDeps(err, getMod);
			mPasses ~= missing;
		} else {
			mPasses ~= new ImportResolver(err, getMod);
		}
	}

	override void transform(ir.Module mod)
	{
		vi.accept(mod, this);

		foreach (p; mPasses) {
			p.transform(mod);
		}
	}

	override void transformChildBlocks(ir.Function func)
	{
		auto mod = getModuleFromScope(/*#ref*/func.loc, func.myScope, mErr);

		if (func.hasInContract) {
			passert(mErr, func, func.parsedIn !is null);
			transform(mod, func, func.parsedIn);
		}

		if (func.hasOutContract) {
			passert(mErr, func, func.parsedOut !is null);
			transform(mod, func, func.parsedOut);
		}

		if (func.hasBody) {
			passert(mErr, func, func.parsedBody !is null);
			transform(mod, func, func.parsedBody);
		}
	}

	override void close()
	{
		foreach (p; mPasses) {
			p.close();
		}
	}

	/*
	 *
	 * Helper code.
	 *
	 */

	void transform(ir.Module mod, ir.Function func, ir.BlockStatement bs)
	{
		vi.accept(bs, this);

		mScope.transform(mod, func, bs);
		mAttrib.transform(mod, func, bs);
		mGatherer.transform(mod, func, bs);
	}

	/*
	 *
	 * Flattening code
	 *
	 */

	override Status enter(ir.TopLevelBlock tlb)
	{
		tlb.nodes = manip(tlb.nodes);
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		bs.statements = manip(bs.statements);
		return Continue;
	}

	// @TODO HACK Once attribute removal code is merged here change visitor.
	override Status enter(ir.Attribute a)
	{
		if (a.members !is null) {
			a.members.nodes = manip(a.members.nodes);
		}
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		// Need to switch over to pure CondRemoval code.

		if (td._struct !is null) {
			return vi.accept(td._struct, mCond);
		}
		if (td._union !is null) {
			return vi.accept(td._union, mCond);
		}
		if (td._interface !is null) {
			return vi.accept(td._interface, mCond);
		}
		if (td._class !is null) {
			return vi.accept(td._class, mCond);
		}
		if (td._function !is null) {
			return vi.accept(td._function, mCond);
		}

		mErr.panic(td, "Invalid TemplateDefinition");
		return Continue;
	}


	/*
	 *
	 * Manip flattening code code.
	 *
	 */

	final ir.Node[] manip(ir.Node[] nodes)
	{
		NodeSink ns;
		handle(/*#ref*/ ns, nodes);
		return ns.toArray();
	}

	final void handle(ref NodeSink ns, ir.Node[] nodes)
	{
		ir.Node[] ret;
		foreach (n; nodes) {
			if (handle(/*#ref*/ ns, n, /*#out*/ ret)) {
				handle(/*#ref*/ ns, ret);
			} else {
				ns.sink(n);
			}
		}
	}

	final bool handle(ref NodeSink ns, ir.Node n, out ir.Node[] ret)
	{
		ir.Node[] nodes;

		switch (n.nodeType) with (ir.NodeType) {
		case ConditionTopLevel:
			auto c = n.toConditionTopLevelFast();
			return mCond.evaluate(c, /*#out*/ ret);
		case ConditionStatement:
			auto c = n.toConditionStatementFast();
			return mCond.evaluate(c, /*#out*/ ret);
		case Unittest:
			// @TODO we currently just remove them.
			return true;
		default:
			// Make caller add this node.
			return false;
		}
	}
}
