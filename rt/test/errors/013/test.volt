//T macro:expect-failure
//T check:invalid '-' expression
module test;

struct Foo
{
    fn blarg() i32 { return 0; }

    fn opCmp(other: Foo) i32
    {
        // Notice missing () after blarg
        return other.blarg - blarg;
    }
}

fn main() i32
{
	return 0;
}
