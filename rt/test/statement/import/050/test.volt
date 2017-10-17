//T macro:importfail
//T check:multiple imports contain
module test;

import foo = [add1, add2];

fn main() i32
{
    return (foo.add(1, 2) + foo.add("aa", "bbb")) - 8; 
}
