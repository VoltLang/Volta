module test;

alias BOOLEAN_TYPE_ALIAS_TOP_SECRET = bool;

fn main() i32
{
	return BOOLEAN_TYPE_ALIAS_TOP_SECRET.max == 1 ? 0 : 1;
}
