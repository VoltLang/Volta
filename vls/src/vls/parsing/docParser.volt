module vls.parsing.docParser;

import watt = [watt.text.sink, watt.json.util];
import vdoc = watt.text.vdoc;

import ir = volta.ir;

class DocParser : vdoc.DocSink
{
public:
	func: ir.Function;
	mainDocumentation: watt.StringSink;
	paramDocumentation: watt.StringSink[];

public:
	this(func: ir.Function)
	{
		this.func = func;
	}

public override:
	fn start(sink: scope (watt.Sink))
	{
	}

	fn end(sink: scope (watt.Sink))
	{
	}

	fn briefStart(sink: scope (watt.Sink))
	{
	}

	fn briefEnd(sink: scope (watt.Sink))
	{
	}

	fn sectionStart(sink: scope (watt.Sink), sec: vdoc.DocSection)
	{
	}

	fn sectionEnd(sink: scope (watt.Sink), sec: vdoc.DocSection)
	{
	}

	fn paramStart(sink: scope (watt.Sink), direction: string, arg: string)
	{
		ss: watt.StringSink;
		paramDocumentation ~= ss;
	}

	fn paramEnd(sink: scope(watt.Sink))
	{
	}

	fn content(sink: scope (watt.Sink), state: vdoc.DocState, d: string)
	{
		final switch (state) with (vdoc.DocState) {
		case Content, Brief, Section: mainDocumentation.sink(new "${d}\n"); break;
		case Param: paramDocumentation[$-1].sink(d); break;
		}
	}

	fn p(sink: scope(watt.Sink), state: vdoc.DocState, d: string)
	{
	}

	fn link(sink: scope (watt.Sink), state: vdoc.DocState,
			target: string, text: string)
	{
	}

	fn defgroup(sink: scope (watt.Sink), group: string, text: string)
	{
	}

	fn ingroup(sink: scope (watt.Sink), group: string)
	{
	}
}

fn getFunctionBodyDoc(func: ir.Function) const(char)[]
{
	dp := new DocParser(func);
	vdoc.parse(func.docComment, dp, null);
	return watt.escapeString(dp.mainDocumentation.toString());
}

fn getFunctionParamDoc(func: ir.Function, i: size_t) const(char)[]
{
	dp := new DocParser(func);
	vdoc.parse(func.docComment, dp, null);
	if (i < dp.paramDocumentation.length) {
		return watt.escapeString(dp.paramDocumentation[i].toString());
	}
	return "";
}

