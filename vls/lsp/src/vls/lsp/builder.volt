/*!
 * Convenience functions for creating JSON LSP response strings.
 */
module vls.lsp.builder;

import core.rt.format : vrt_format_i64;
import watt = watt.text.sink;
import json = watt.json;

import vls.lsp.constants : DiagnosticLevel, MessageType;

// interface Position

fn buildPosition(line: i32, column: i32) string
{
	ss: watt.StringSink;
	buildPosition(ss.sink, line, column);
	return ss.toString();
}

fn buildPosition(sink: watt.Sink, line: i32, column: i32)
{
	sink(`{"line":`);
	vrt_format_i64(sink, line);
	sink(`,"character":`);
	vrt_format_i64(sink, column);
	sink("}");
}

// interface Range

fn buildRange(line1: i32, column1: i32, line2: i32, column2: i32) string
{
	ss: watt.StringSink;
	buildRange(ss.sink, line1, column1, line2, column2);
	return ss.toString();
}

fn buildRange(sink: watt.Sink, line1: i32, column1: i32, line2: i32, column2: i32)
{
	sink(`{"start":`);
	buildPosition(sink, line1, column1);
	sink(`,"end":`);
	buildPosition(sink, line2, column2);
	sink("}");
}

fn buildRange(sink: watt.Sink, line: i32)
{
	buildRange(sink, line, 0, line+1, 0);
}

fn buildRange(sink: watt.Sink, line: i32, column: i32)
{
	buildRange(sink, line, column, line, column + 1);
}

// interface Location

fn buildLocation(uri: string, line: i32, column: i32) string
{
	ss: watt.StringSink;
	buildLocation(ss.sink, uri, line, column);
	return ss.toString();
}

fn buildLocation(uri: string, line: i32) string
{
	ss: watt.StringSink;
	buildLocation(ss.sink, uri, line);
	return ss.toString();
}

fn buildLocation(sink: watt.Sink, uri: string, line: i32, column: i32)
{
	sink(`{"uri":"`);
	sink(uri);
	sink(`,"range":`);
	buildRange(sink, line, column);
	sink("}");
}

fn buildLocation(sink: watt.Sink, uri: string, line: i32)
{
	sink(`{"uri":"`);
	sink(uri);
	sink(`,"range":`);
	buildRange(sink, line);
	sink("}");
}

// publish Diagnostic

fn buildNoDiagnostic(uri: string) string
{
	ss: watt.StringSink;
	buildNoDiagnostic(ss.sink, uri);
	return ss.toString();
}

fn buildNoDiagnostic(sink: watt.Sink, uri: string)
{
	sink(`{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"`);
	sink(uri);
	sink(`","diagnostics":[]}}`);
}

fn buildDiagnostic(uri: string, line: i32, column: i32, severity: DiagnosticLevel, msg: string,
	buildTag: string = null) string
{
	ss: watt.StringSink;
	buildDiagnostic(ss.sink, uri, line, column, severity, msg, buildTag);
	return ss.toString();
}

fn buildDiagnostic(sink: watt.Sink, uri: string, line: i32, column: i32, severity: DiagnosticLevel, msg: string,
	buildTag: string = null)
{
	sink(`{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"`);
	sink(uri);
	sink(`","diagnostics":[{"range":`);
	buildRange(sink, line, column);
	sink(`,"severity":`);
	vrt_format_i64(sink, severity);
	sink(`,"message":"`);
	sink(json.escapeString(msg));
	sink(`"}]`);
	if (buildTag !is null) {
		sink(`,"buildTag":"`);
		sink(json.escapeString(buildTag));
		sink(`"`);
	}
	sink(`}}`);
}

// window/showMessage notification

fn buildShowMessage(type: MessageType, msg: string) string
{
	ss: watt.StringSink;
	buildShowMessage(ss.sink, type, msg);
	return ss.toString();
}

fn buildShowMessage(sink: watt.Sink, type: MessageType, msg: string)
{
	sink(`{"jsonrpc":"2.0","method":"window/showMessage","params":{"type":`);
	vrt_format_i64(sink, type);
	sink(`,"message":"`);
	sink(json.escapeString(msg));
	sink(`"}}`);
}

// vls/buildSuccess notification

fn buildVlsBuildSuccessNotification(buildTag: string) string
{
	ss: watt.StringSink;
	buildVlsCustomBuildTagNotification(ss.sink, "vls/buildSuccess", buildTag);
	return ss.toString();
}

fn buildVlsBuildPendingNotification(buildTag: string) string
{
	ss: watt.StringSink;
	buildVlsCustomBuildTagNotification(ss.sink, "vls/buildPending", buildTag);
	return ss.toString();
}

fn buildVlsCustomBuildTagNotification(sink: watt.Sink, methodName: string, buildTag: string)
{
	sink(`{"jsonrpc":"2.0","method":"`);
	sink(methodName);
	sink(`","params":{"buildTag":"`);
	sink(json.escapeString(buildTag));
	sink(`"}}`);
}