//T macro:expect-failure
//T check:static field 'init' collides
module test;

struct S
{
    local init: i32;
}

fn main() i32
{
    S.init = 32;
    return S.init - 32;
}
