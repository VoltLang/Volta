module test;


@property fn four() i32 { return 4; }

class PlusTwoFactory
{
    mX: i32;

    this(x: i32)
    {
        mX = x + 2;
        return;
    }

    fn get() i32
    {
        return mX;
    }
}

fn main() i32
{
    factory := new PlusTwoFactory(four);
    return factory.get() - 6;
}
