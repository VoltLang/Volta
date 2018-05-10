module vls.lsp.constants;

enum Listening
{
	Stop = false,
	Continue = true,
}

enum Header
{
	Length = "Content-Length",
	Type   = "Content-Type",
}

enum ErrorCode
{
	ServerEnd     = -32000,
	InvalidParams = -32602,
}

enum SymbolType
{
	File = 1,
	Module,
	Namespace,
	Package,
	Class,
	Method,
	Property,
	Field,
	Constructor,
	Enum,
	Interface,
	Function,
	Variable,
	Constant,
	String,
	Number,
	Boolean,
	Array,
}

enum DiagnosticLevel
{
	Error = 1,
	Warning,
	Info,
	Hint,
}

enum FileChanged
{
	Created = 1,
	Changed,
	Deleted,
}

enum CompletionType
{
	Text = 1,
	Method,
	Function,
	Constructor,
	Field,
	Variable,
	Class,
	Interface,
	Module,
	Property,
	Unit,
	Value,
	Enum,
	Keyword,
	Snippet,
	Colour,
	File,
	Reference,
	Folder,
	EnumMember,
	Constant,
	Struct,
	Event,
	Operator,
	TypeParameter,
}
