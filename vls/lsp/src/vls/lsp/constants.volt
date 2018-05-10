module vls.lsp.constants;

/* @todo this should work
enum Listening : bool
{
	Stop = false,
	Continue = true,
}*/
struct Listening
{
	enum Stop = false;
	enum Continue = true;
}

/* @todo this should work
enum Header : string
{
	Length = "Content-Length",
	Type   = "Content-Type",
}*/
struct Header
{
	enum Length = "Content-Length";
	enum Type   = "Content-Type";
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
