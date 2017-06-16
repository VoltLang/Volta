module test;

import core.rt.format;

fn main() i32
{
	string outString;
	fn sink(arg: SinkArg)
	{
		outString ~= new string(arg);
	}
	vrt_format_f64(sink, 3.1, -1);
	if (outString != "3.100000") {
		return 1;
	}
	return 0;
}
