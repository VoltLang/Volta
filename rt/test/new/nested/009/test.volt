module test;

fn main() i32
{
	fn foo() { return; }
	return typeid(foo).mangledName == typeid(scope dg()).mangledName ? 0 : 42;
}
