module test;

alias IA = immutable(void)[];

fn main() i32
{
	a := [1, 2, 3];
	b := cast(IA)a;
	bool[IA] c;
	c[cast(IA)b] = true;
	return 0;
}
