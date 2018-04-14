/*#D*/
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.util.dup;

version (Volt): // Needed, Volt doesn't have dup.

import ir = volta.ir;


/*
 *
 * Base type dups
 *
 */

bool[] dup(bool[] arr) { return new arr[0 .. $]; }
string[] dup(string[] arr) { return new arr[0 .. $]; }
size_t[] dup(size_t[] arr) { return new arr[0 .. $]; }


/*
 *
 * ir dups
 *
 */

ir.Exp[] dup(ir.Exp[] arr) { return new arr[0 .. $]; }
ir.Node[] dup(ir.Node[] arr) { return new arr[0 .. $]; }
ir.Type[] dup(ir.Type[] arr) { return new arr[0 .. $]; }
ir.Token[] dup(ir.Token[] arr) { return new arr[0 .. $]; }
ir.AAPair[] dup(ir.AAPair[] arr) { return new arr[0 .. $]; }
ir.Module[] dup(ir.Module[] arr) { return new arr[0 .. $]; }
ir.Variable[] dup(ir.Variable[] arr) { return new arr[0 .. $]; }
ir.Function[] dup(ir.Function[] arr) { return new arr[0 .. $]; }
ir.Attribute[] dup(ir.Attribute[] arr) { return new arr[0 .. $]; }
ir.Function[][] dup(ir.Function[][] arr) { return new arr[0 .. $]; }
ir.SwitchCase[] dup(ir.SwitchCase[] arr) { return new arr[0 .. $]; }
ir._Interface[] dup(ir._Interface[] arr) { return new arr[0 .. $]; }
ir.Identifier[] dup(ir.Identifier[] arr) { return new arr[0 .. $]; }
ir.Identifier[][] dup(ir.Identifier[][] arr) { return new arr[0 .. $]; }
ir.FunctionParam[] dup(ir.FunctionParam[] arr) { return new arr[0 .. $]; }
ir.TypeReference[] dup(ir.TypeReference[] arr) { return new arr[0 .. $]; }
ir.QualifiedName[] dup(ir.QualifiedName[] arr) { return new arr[0 .. $]; }
ir.BlockStatement[] dup(ir.BlockStatement[] arr) { return new arr[0 .. $]; }
ir.Postfix.TagKind[] dup(ir.Postfix.TagKind[] arr) { return new arr[0 .. $]; }
ir.EnumDeclaration[] dup(ir.EnumDeclaration[] arr) { return new arr[0 .. $]; }
ir.FunctionParameter[] dup(ir.FunctionParameter[] arr) { return new arr[0 .. $]; }
ir.TemplateDefinition.Parameter[] dup(ir.TemplateDefinition.Parameter[] arr) { return new arr[0 .. $]; }


/*
 *
 * Idups
 *
 */

immutable(void)[] idup(const(void)[] arr)
{
	return cast(immutable(void)[]) new arr[0 .. $];
}
