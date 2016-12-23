//T compiles:yes
//T retval:0
module test;

struct Line {
}

private Line[] parseLines(ref string[] lines)
{
	Line[] ret;
	for (size_t i = 0; i < lines.length; ++i) {
		while (false) {
			void codeIndent()
			{
			}
		}
	}
	return ret;
}

int main()
{
	string[] lines = ["a", "b"];
	parseLines(ref lines);
	return 0;
}
