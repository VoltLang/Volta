/*!
 * Convenience functions for creating JSON LSP response strings.
 */
module vls.lsp.builder;

import vls.lsp.util;

fn buildNoDiagnostic(uri: string) string
{
	msg := new "{
		\"jsonrpc\": \"2.0\",
		\"method\": \"textDocument/publishDiagnostics\",
		\"params\": {
			\"uri\": \"${uri}\",
			\"diagnostics\": []
		}
	}";
	return compress(msg);
}
