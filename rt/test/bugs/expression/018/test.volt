module test;

fn main() i32 {
	return cast(i32) typeid(scope dg(i32)).args.length - 1;
}

