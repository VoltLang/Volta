// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.typeverifier;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;

/**
 * The type verifier verifies types.
 *
 * Firstly, it determines whether or not all user defined types
 * are 'well defined'. That is to say, that they can be instantiated
 * -- so no recursive types, or types using undefined objects.
 */
class TypeDefinitionVerifier : NullVisitor, Pass
{
public:
	int undefinedTypes;

public:
	bool verify(ir.Node n, bool fromInternal)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case Struct:
			auto asStruct = cast(ir.Struct) n;
			assert(asStruct !is null);
			return verify(asStruct, true);
		case Class:
			auto asClass = cast(ir.Class) n;
			assert(asClass !is null);
			return verify(asClass, true);
		case Interface:
			auto asInterface = cast(ir._Interface) n;
			assert(asInterface !is null);
			return verify(asInterface, true);
		case Variable:
			auto asVariable = cast(ir.Variable) n;
			assert(asVariable !is null);
			return verify(asVariable.type, true);
		case TypeReference:
			auto asUser = cast(ir.TypeReference) n;
			assert(asUser !is null);
			return verify(asUser.type, true);
		case Function:
			auto asFunction = cast(ir.Function) n;
			assert(asFunction !is null);
			return verify(asFunction, true);
		default:
			// Pointers, Arrays, and AAs to UserTypes are treated as defined
			// as the only time they are in error, is when the identifier doesn't
			// exist at _all_, and that case is handled by the UserResolver pass.
			return true;
		}
	}

	bool verify(ir.Function fn, bool fromInternal)
	{
		assert(fn !is null);
		if (fn.defined || fromInternal) {
			return fn.defined;
		}

		bool defined = true;

		defined = defined && verify(fn.type.ret, true);
		foreach (param; fn.type.params) {
			defined = defined && verify(param.type, true);
		}

		if (!defined) {
			undefinedTypes++;
		}
		return fn.defined = defined;
	}

	// Knuth, please forgive me for the copy and paste. -bah

	bool verify(ir.Struct s, bool fromInternal)
	{
		assert(s !is null);
		if (s.defined || fromInternal) {
			return s.defined;
		}

		bool defined = true;
		foreach (member; s.members) {
			defined = defined && verify(member, true);
		}

		if (!defined) {
			undefinedTypes++;
		}
		return s.defined = defined;
	}

	bool verify(ir.Class c, bool fromInternal)
	{
		assert(c !is null);
		if (c.defined || fromInternal) {
			return c.defined;
		}

		bool defined = true;
		foreach (member; c.members) {
			defined = defined && verify(member, true);
		}

		if (!defined) {
			undefinedTypes++;
		}
		return c.defined = defined;
	}

	bool verify(ir._Interface i, bool fromInternal)
	{
		assert(i !is null);
		if (i.defined || fromInternal) {
			return i.defined;
		}

		bool defined = true;
		foreach (member; i.members) {
			defined = defined && verify(member, true);
		}

		if (!defined) {
			undefinedTypes++;
		}
		return i.defined = defined;
	}

	override void transform(ir.Module m)
	{
		accept(m, this);

		while (undefinedTypes > 0) {
			int oldUndefined = undefinedTypes;
			undefinedTypes = 0;
			accept(m, this);
			if (undefinedTypes == oldUndefined) {
				// Temporary error message.
				throw new CompilerError(m.location, "circular definition.");
			}
		}
	}

	override void close()
	{
	}

	override Status enter(ir.Struct s)
	{
		verify(s, false);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		verify(c, false);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		verify(i, false);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		verify(fn, false);
		return Continue;
	}
}
