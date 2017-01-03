module test;

struct Line
{
}

private fn parseLines(ref lines: string[]) Line[]
{
	ret: Line[];
	for (i: size_t = 0; i < lines.length; ++i) {
		while (false) {
			fn codeIndent()
			{
			}
		}
	}
	return ret;
}

fn main() i32
{
	lines: string[] = ["a", "b"];
	parseLines(ref lines);
	return 0;
}
