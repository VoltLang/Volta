module vls.modules;

import watt       = [
	watt.io,
	watt.path,
	watt.io.file,
	watt.text.string,
	watt.text.path,
];

import ir        = volta.ir;
import volta     = [
	volta.interfaces,
	volta.settings,
];

import lsp       = vls.lsp;
import parser    = vls.parser;
import documents = vls.documents;

/*!
 * Get the module associated with `moduleName`, or `null`.
 */
fn get(moduleName: ir.QualifiedName) ir.Module
{
	if (p := moduleName.toString() in gModules) {
		return *p;
	}
	return null;
}

fn get(moduleName: ir.QualifiedName, uri: string, errorSink: volta.ErrorSink, settings: volta.Settings) ir.Module
{
	mod := get(moduleName);
	if (mod !is null) {
		return mod;
	}
	return findAndParseFailedGet(moduleName, uri, errorSink, settings);
}

/*!
 * Associate `_module` with `moduleName`.
 */
fn set(moduleName: ir.QualifiedName, _module: ir.Module)
{
	gModules[moduleName.toString()] = _module;
}

private:

fn findAndParseFailedGet(moduleName: ir.QualifiedName, uri: string, errorSink: volta.ErrorSink, settings: volta.Settings) ir.Module
{
	path := lsp.getPathFromUri(uri);
	base := watt.dirName(lsp.getBatteryToml(path));
	version (Windows) base = watt.replace(base, "\\", "/");
	modpath := findLocal(base, moduleName);
	if (modpath is null) {
		return null;
	}
	text   := cast(string)watt.read(modpath);
	moduri := lsp.getUriFromPath(modpath);
	documents.set(moduri, text);
	return parser.fullParse(moduri, errorSink, settings);
}

fn findLocal(base: string, moduleName: ir.QualifiedName) string
{
	proposedPath := watt.concatenatePath(base, "src");
	idents := moduleName.identifiers;
	foreach (i, ident; idents) {
		if (!watt.isDir(proposedPath)) {
			return null;
		}
		proposedPath = watt.concatenatePath(proposedPath, ident.value);
		if (i < idents.length - 1) {
			continue;
		}
		// Last ident.
		voltExtension := new "${proposedPath}.volt";
		if (watt.exists(voltExtension)) {
			return voltExtension;
		}
	}
	return null;
}

global gModules: ir.Module[string];
