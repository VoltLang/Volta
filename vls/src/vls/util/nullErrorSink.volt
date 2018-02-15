/*!
 * An error sink that does nothing with errors.
 */
module vls.util.nullErrorSink;

import ir    = volta.ir;
import volta = volta.interfaces;

//! Get the null error sink instance.
fn get() volta.ErrorSink
{
	if (gInstance is null) {
		gInstance = new NullErrorSink();
	}
	return gInstance;
}

private:

local gInstance: NullErrorSink;

class NullErrorSink : volta.ErrorSink
{
public:
override:
	fn onWarning(msg: string, file: string, line: i32) {}
	fn onWarning(ref in loc: ir.Location, msg: string, file: string, line: i32) {}
	fn onError(msg: string, file: string, line: i32) {}
	fn onError(ref in loc: ir.Location, msg: string, file: string, line: i32) {}
	fn onPanic(msg: string, file: string, line: i32) {}
	fn onPanic(ref in loc: ir.Location, msg: string, file: string, line: i32) {}
}
