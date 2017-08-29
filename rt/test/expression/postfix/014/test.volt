module test;

interface IFoo
{
	fn aNumber() i32;
}

class Foo : IFoo
{
    override fn aNumber() i32 { return 12; }
}

class Indirection
{
    fn getFoo() IFoo
    {
        return new Foo();
    }
}

fn main() i32
{
    i := new Indirection();
    return i.getFoo().aNumber() - 12;
}
