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

//! For testing purposes.
fn setModulePath(path: string)
{
	gModulePath = path;
}

fn setPackagePath(_package: string, path: string, relativeSrc: string = null)
{
	if (checkTestPaths(_package, path)) {
		return;
	}
	finalPath: string;
	if (relativeSrc !is null) {
		finalPath = watt.concatenatePath(path, relativeSrc);
	} else {
		finalPath = path;
	}
	gPackagePath[_package] = finalPath;
}

private:

global gModules: ir.Module[string];
global gModulePath: string;
global gPackagePath: string[string];

fn getSrcFolder(path: string) string
{
	if (gModulePath !is null) {
		return gModulePath;
	}
	bpath := watt.dirName(lsp.getBatteryToml(path));
	return watt.concatenatePath(bpath, "src");
}

fn findAndParseFailedGet(moduleName: ir.QualifiedName, uri: string, errorSink: volta.ErrorSink, settings: volta.Settings) ir.Module
{
	path := lsp.getPathFromUri(uri);
	base := getSrcFolder(path);
	if (base is null) {
		return null;
	}
	modpath: string;
	if (p := moduleName.identifiers[0].value in gPackagePath) {
		modpath = findLocal(*p, moduleName);
	} else {
		modpath = findLocal(base, moduleName);
	}
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
	proposedPath := base;
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
		normalModule := sourceFileExists(proposedPath);
		if (normalModule !is null) {
			return normalModule;
		}
		packageExtension := sourceFileExists(watt.concatenatePath(proposedPath, "package"));
		if (packageExtension !is null) {
			return packageExtension;
		}
	}
	return null;
}

/*!
 * If `${base}.volt` or `${base}.d` exists, return that path.
 * Otherwise return `null`.
 */
fn sourceFileExists(base: string) string
{
	vExtension := new "${base}.volt";
	if (watt.exists(vExtension)) {
		return vExtension;
	}
	dExtension := new "${base}.d";
	if (watt.exists(dExtension)) {
		return dExtension;
	}
	return null;
}

/* If we want to test Watt etc in the unittests,
 * we doctor the input to set the library paths
 * to testwatt testvolta etc. This triggers us to
 * search upwards from the vls executable for the
 * appropriate paths.
 */

fn checkTestPaths(_package: string, path: string) bool
{
	if (_package == "watt" && path == "testwatt") {
		p := findParentFolder(watt.getExecDir(), "Watt/src");
		if (p !is null) {
			gPackagePath["watt"] = p;
			return true;
		}
	}
	if (_package == "core" && path == "testvolta") {
		p := findParentFolder(watt.getExecDir(), "Volta/rt/src");
		if (p !is null) {
			gPackagePath["core"] = p;
			return true;
		}
	}
	return false;
}

fn findParentFolder(basePath: string, additionalPath: string) string
{
	while (basePath.length > 0) {
		bpath := watt.concatenatePath(basePath, additionalPath);
		if (watt.isDir(bpath)) {
			return bpath;
		}
		lsp.parentDirectory(ref basePath);
	}
	return null;
}