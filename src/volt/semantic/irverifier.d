// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.irverifier;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import volt.semantic.classify;


/**
 * This verifier is design to catch faulty IR (from the view
 * of the backends) that the LanguagePass generate.
 *
 * Such as implicit casts or parser nodes that should have
 * been cleaned or uninitialized fields (such as magnedName).
 *
 * @ingroup passes passLang
 */
class IrVerifier : ScopeManager, Pass
{
private:
	int[size_t] mNodes;
	int mCount;

public:
	override void transform(ir.Module m)
	{
		version (Volt) {
			mNodes = [];
		} else {
			mNodes = null;
		}
		mCount = 0;
		accept(m, this);
	}

	override void close()
	{
	}


public:
	override Status debugVisitNode(ir.Node n)
	{
		auto t = *cast(size_t*)&n;
		if (t in mNodes) {
			auto str = format(
				"%s \"%s\" node found more then once in IR",
				ir.getNodeAddressString(n), ir.nodeToString(n));
			throw panic(n, str);
		}
		mNodes[t] = mCount++;

		return Status.Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.storage != ir.Variable.Storage.Invalid) {
			return Continue;
		}
		auto str = format("%s invalid variable found in IR",
		                  ir.getNodeAddressString(v));
		throw panic(v, str);
	}

	override Status enter(ir.StorageType st)
	{
		throw panic(st, "storage type found in IR.");
	}

	override Status visit(ir.TypeReference tr)
	{
		if (tr.type is null) {
			throw panic(tr, "TypeReference.type is null");
		}
		if (tr.type.nodeType != ir.NodeType.Enum &&
		    tr.type.nodeType != ir.NodeType.Class &&
		    tr.type.nodeType != ir.NodeType.Union &&
		    tr.type.nodeType != ir.NodeType.Struct &&
		    tr.type.nodeType != ir.NodeType.Interface &&
		    tr.type.nodeType != ir.NodeType.UserAttribute) {
			throw panic(tr, "TypeReference.type is points to invalid class");
		}
		return Continue;
	}

	override Status enter(ir.FunctionType ct)
	{
		if (ct.params.length != ct.isArgRef.length ||
		    ct.params.length != ct.isArgOut.length) {
			throw panic(ct, "isArg[Ref|Out] length doesn't match");
		}
		return Continue;
	}

	override Status enter(ir.DelegateType ct)
	{
		if (ct.params.length != ct.isArgRef.length ||
		    ct.params.length != ct.isArgOut.length) {
			throw panic(ct, "isArg[Ref|Out] length doesn't match");
		}
		return Continue;
	}

	override Status enter(ir.TopLevelBlock tlb)
	{
		foreach (n; tlb.nodes) {
			switch (n.nodeType) with (ir.NodeType) {
			case Import:
				// Check if in top level module.
				goto case;
			case Variable:
			case Function:
			case Alias:
			case Enum:
			case Struct:
			case Union:
			case Class:
			case Interface:
			case MixinFunction:
			case MixinTemplate:
			case MixinStatement:
			case UserAttribute:
			case EnumDeclaration:
				auto s = accept(n, this);
				if (s == Stop)
					return Stop;
				break;
			default:
				auto str = format("%s invalid node '%s' in toplevel block",
				                  ir.getNodeAddressString(n),
				                  ir.nodeToString(n));
				throw panic(n, str);
			}
		}

		return ContinueParent;
	}

	override Status enter(ir.BlockStatement bs)
	{
		foreach (n; bs.statements) {
			switch (n.nodeType) with (ir.NodeType) {
			case BlockStatement:
			case ReturnStatement:
			case IfStatement:
			case WhileStatement:
			case DoStatement:
			case ForStatement:
			case ForeachStatement:
			case BreakStatement:
			case ContinueStatement:
			case ExpStatement:
			case Variable:
			case MixinStatement:
			case ThrowStatement:
			case SwitchStatement:
			case GotoStatement:
			case AssertStatement:
			case WithStatement:
			case ScopeStatement:
			case TryStatement:
				auto s = accept(n, this);
				if (s == Stop)
					return Stop;
				break;
			case Function:
			case Struct:
				break;
			default:
				auto str = format("(%s) invalid node '%s' in block statement",
				                  ir.getNodeAddressString(n),
				                  ir.nodeToString(n));
				throw panic(n, str);
			}
		}

		return ContinueParent;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		auto str = format("%s IdentifierExp '%s' left in IR.",
		                  ir.getNodeAddressString(ie), ie.value);
		throw panic(ie, str);
	}

	override Status leave(ir.TopLevelBlock tlb) { assert(false); }
	override Status leave(ir.BlockStatement bs) { assert(false); }
}
