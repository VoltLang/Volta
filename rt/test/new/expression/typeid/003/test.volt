module test;

fn main() i32
{
	x: size_t = typeid(i32).size;
	x += typeid(i16[]).base.size;
	x += typeid(i16[3]).staticArrayLength;
	x += typeid(i8[i64]).key.size + typeid(i16[i64]).value.size;
	x += typeid(fn(i8, i16) i16).ret.size + typeid(fn(i8, i16) i16).args.length;
	return cast(i32) x - 23;
}
