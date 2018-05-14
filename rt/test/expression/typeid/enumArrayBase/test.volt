module test;

enum Enum
{
	Declaration = "a string"
}

enum Char = 12;
enum Array = 26;

fn main() i32
{
	tid := typeid(Enum.Declaration);
	if (tid.type != Array) {
		return 1;
	}
	if (tid.base is null) {
		return 2;
	}
	if (tid.base.type != Char) {
		return 3;
	}
	return 0;
}
