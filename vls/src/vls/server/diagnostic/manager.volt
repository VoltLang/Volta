module vls.server.diagnostic.manager;

import core.rt.thread;

import ir = volta.ir;
import vls.lsp;
import vls.server.responses;

import vls.server.diagnostic.diagnostic;

/*!
 * Manages diagnostic messages.
 *
 * The server (that's us!) 'owns' error messages, and we take responsibility
 * for clearing them etc.  
 * When the completion code finds an error (or not) in a module, it is reported
 * (or cleared) at that point. This is complicated when we launch a battery
 * instance to build a project. The diagnostic manager will note the root
 * for which the error was generated, as well as the URI it's associated with,
 * and the only thing that will clear that error message is another error
 * message from battery from the same root, or a battery run for the same
 * root completing successfully.
 *
 * This class should be solely responsible for sending `textDocument/publishDiagnostics`
 * responses.
 */
class Manager
{
private:
	mDiagnostics: Diagnostics*[string];

public:
	/*!
	 * Remove any errors associated with a given battery root,
	 * or associated with no battery root.
	 *
	 * If changes are made, this sends a message to the client.
	 */
	fn clearBatteryRoot(batteryRoot: string)
	{
		uris := mDiagnostics.keys;

		foreach (uri; uris) {
			da := mDiagnostics[uri];
			if (da.arr.length == 0) {
				continue;
			}

			mDiagnostics[uri].clear();
			foreach (d; da.arr) {
				if (d.batteryRoot != batteryRoot) {
					addDiagnostic(d);
				}
			}

			dp := uri in mDiagnostics;
			if (dp is null) {
				reportNoDiagnostic(uri);
				return;
			}
		}

		reportToClient();
	}

	/*!
	 * Remove any errors associated with the given uri not associated with a battery root.
	 *
	 * If changes are made, this sends a message to the client.
	 */
	fn clearUri(uri: string)
	{
		dp := uri in mDiagnostics;
		if (dp is null || (*dp).arr.length == 0) {
			return;
		}

		arr := (*dp).arr;
		mDiagnostics[uri].clear();
		foreach (d; arr) {
			if (d.batteryRoot.length > 0) {
				addDiagnostic(d);
			}
		}

		dp = uri in mDiagnostics;
		if (dp is null || (*dp).arr.length == 0) {
			reportNoDiagnostic(uri);
			return;
		}

		reportToClient();
	}

	/* Associate a diagnostic with a uri.
	 *
	 * The important thing is that diagnostics not associated with a build
	 * don't clobber those that are, and that a diagnostic associated with
	 * a build overrides the current set, no matter the contents.
	 */
	fn addDiagnostic(diagnostic: Diagnostic)
	{
		dp := diagnostic.uri in mDiagnostics;
		if (dp is null) {
			mDiagnostics[diagnostic.uri] = new Diagnostics;
		}
		mDiagnostics[diagnostic.uri].add(diagnostic);
		reportToClient();
	}

private:
	fn reportToClient()
	{
		foreach (uri, diagnostics; mDiagnostics) {
			send(diagnostics.response(uri));
		}
	}

	fn reportNoDiagnostic(uri: string)
	{
		send(notificationNoDiagnostic(uri));
	}
}