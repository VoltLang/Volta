module test;

import vrt.os.format;
import core.rt.format : Sink, SinkArg;

fn getVoltString(d: f64) string
{
	s: string;
	fn sink(ss: SinkArg)
	{
		s ~= new string(ss);
	}
	vrt_format_f64(sink, d, 3);
	return s;
}

fn main() i32
{
	d := 3042.1415926538;
	if (getVoltString(d) != "3042.142") {
		return 1;
	}
	return 0;
}
