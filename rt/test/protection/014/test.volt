module test;

class P
{
protected:
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
