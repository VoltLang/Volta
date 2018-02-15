module vls.lsp.message;

struct LspMessage
{
	contentLength: size_t;
	content: string;
}
