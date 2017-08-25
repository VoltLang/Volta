//T macro:syntax-only
module test;

struct Foo = mixin OneArg!i32;
union Foo = mixin OneArgWithSigil!i32*;
class Foo = mixin TwoArg!(i32, i16);
fn Foo = mixin FunctionInstance!User[32];

