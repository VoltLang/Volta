module vls.lsp.message;

struct LspMessage
{
	contentLength: size_t;
	content: string;

	@property fn dup() LspMessage
	{
		msg: LspMessage;
		msg.contentLength = contentLength;
		msg.content = new content[..];
		return msg;
	}
}
