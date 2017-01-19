module test;

import vrt.os.format : vrt_format_f64;
import core.rt.format;

fn main() i32
{
	string outString;
	fn sink(arg: SinkArg)
	{
		outString ~= new string(arg);
	}
	vrt_format_f64(sink, 3.1415926538, -1);
	if (outString != "3.141593") {
		return 1;
	}
	return 0;
}
