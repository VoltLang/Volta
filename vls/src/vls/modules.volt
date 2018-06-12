module vls.modules;

import io = watt.io;

import ir = volta.ir;

import parser = vls.parser;

/*!
 * Get the module associated with `moduleName`, or `null`.
 */
fn get(moduleName: ir.QualifiedName) ir.Module
{
	io.error.writeln(new "get(${moduleName})");
	if (p := moduleName.toString() in gModules) {
		return *p;
	}
	return null;
}

/*!
 * Associate `_module` with `moduleName`.
 */
fn set(moduleName: ir.QualifiedName, _module: ir.Module)
{
	gModules[moduleName.toString()] = _module;
}

private:

global gModules: ir.Module[string];
