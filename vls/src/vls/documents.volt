module vls.documents;

import io = watt.io;
import lsp = vls.lsp;

/*!
 * Handle a textDocument update request. Returns the uri, or `null`.
 */
fn handleUpdate(request: lsp.RequestObject) string
{
	if (!isUpdateRequest(request.methodName)) {
		io.error.writeln("BAD REQUEST");
		return null;
	}
	root := request.params.lookupObjectKey("textDocument");
	text: string;

	switch (request.methodName) {
	case "textDocument/didSave":
		text = request.params.lookupObjectKey("text").str();
		break;
	case "textDocument/didOpen":
		text = root.lookupObjectKey("text").str();
		break;
	case "textDocument/didChange":
		changes := request.params.lookupObjectKey("contentChanges").array();
		if (changes.length != 1) {
			io.error.writeln("BAD DID CHANGE");
			return null;
		}
		text = changes[0].lookupObjectKey("text").str();
		break;
	default:
		assert(false);
	}

	uri      := root.lookupObjectKey("uri").str();
	_version := root.lookupObjectKey("version").integer();
	setEntry(uri, _version, text);
	return uri;
}

fn get(uri: string) string
{
	if (p := uri in gDocuments) {
		return p.text;
	}
	return null;
}

/*!
 * Associate `uri` with `text`, regardless of current
 * association.
 */
fn set(uri: string, text: string)
{
	gDocuments.remove(uri);
	setEntry(uri, 0, text);
}

private:

struct Entry
{
	_version: i64;
	text:     string;
}

global gDocuments: Entry[string];

fn isUpdateRequest(methodName: string) bool
{
	return methodName == "textDocument/didSave" ||
		methodName == "textDocument/didOpen" ||
		methodName == "textDocument/didChange";
}

/*!
 * Associate `text` with `uri`, if `_version` is greater than the last version used.
 */
fn setEntry(uri: string, _version: i64, text: string)
{
	if (p := uri in gDocuments) {
		if (p._version > _version) {
			return;
		}
	}

	e: Entry;
	e._version = _version;
	e.text = text;
	gDocuments[uri] = e;
}
