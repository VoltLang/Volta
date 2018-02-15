module vls.lsp.util;

import watt = [watt.text.string, watt.text.path, watt.io];

//! @Returns The directory where a URI file resides, or `null`.
fn getPathFromUri(uri: string) string
{
	if (uri.length < 8 || uri[0 .. 8] != "file:///") {
		return null;
	}
	version (Windows) {
		trimAmount := 8;
	} else {
		trimAmount := 7;
	}
	uri = uri[trimAmount .. $];
	uri = watt.replace(uri, "%3A", ":");
	return uri;
}

//! @Returns `path` as a URI.
fn getUriFromPath(path: string) string
{
	if (path is null) {
		return null;
	}
	uri := watt.normalizePath(path);
	version (Windows) {
		uri = watt.replace(uri, ":", "%3A");
		uri = watt.replace(uri, "\\", "/");
	}
	uri = new "file:///${uri}";
	return uri;
}