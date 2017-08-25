//T macro:expect-failure
//T check:access
module test;

class P
{
public:
  fn foo() {}
}

class C : P
{
protected:
  override fn foo() {}
}

fn main() i32
{
	return 0;
}
