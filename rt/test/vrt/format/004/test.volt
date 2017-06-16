module test;

import core.rt.format;

extern(C) fn snprintf(char*, n: size_t, const(char)*, ...) size_t;

fn getVoltString(d: f64) string
{
	s: string;
	fn sink(ss: SinkArg)
	{
		s ~= new string(ss);
	}
	vrt_format_f64(sink, d, -1);
	return s;
}

fn getCString(d: f64) string
{
	s := new char[](1024);
	length := snprintf(s.ptr, s.length, "%f".ptr, d);
	return new string(s[0 .. length]);
}

fn main() i32
{
	d := -1000.0;
	failures := 0;
	while (d < 1000.0) {
		if (getVoltString(d) != getCString(d)) {
			failures++;
		}
		d += 0.1;
	}
	return failures == 0 ? 0 : 1;
}
