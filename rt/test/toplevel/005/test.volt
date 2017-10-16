//T macro:importfail
//T check:tried to access private symbol
module test;

import clazz;

fn main() i32
{
    c := new Clazz();
    return 0;
}
