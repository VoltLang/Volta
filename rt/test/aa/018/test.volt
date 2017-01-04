// AA literals.
module test;

fn main() i32
{
	aa: string[string] = ["volt":"rox"];
	return aa["volt"].length == 3 ? 0 : 1;
}
