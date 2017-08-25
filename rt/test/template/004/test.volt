//T macro:expect-failure
//T check:expected
module test;

struct Foo = mixin Bar!(Baz!i32);

