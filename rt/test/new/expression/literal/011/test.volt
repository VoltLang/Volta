module test;

fn main() i32
{
	s: string = `\`;
	ss: string = "\''";
	sss: string = r"\";
	return cast(int) (s.length + ss.length + sss.length) - 4;
}
