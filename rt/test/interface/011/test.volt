module test;

//
// This is a diamond pattern bug in the interface code.
//
// ImplementsIface2 uses ImplementsIface1 to implement the
// Iface1 interface part of implements iface2.
//
//                             +------+
//          +------------------+Iface1|
//          |                  +---+--+
//          |                      |
//          |                      |
//          |                      |
//          |                      |
//  +-------v--------+         +---v--+
//  |ImplementsIface1|         |Iface2|
//  +-------+--------+         +---+--+
//          |                      |
//          +----------------------+
//          |
//  +-------v--------+
//  |ImplementsIface2|
//  +----------------+
//

interface Iface1
{
	fn func1() i32;
}

interface Iface2 : Iface1
{
	fn func2() i32;
}

class ImplementsIface1 : Iface1
{
	override fn func1() i32 { return 5; }
}

class ImplementsIface2 : ImplementsIface1, Iface2
{
	override fn func2() i32 { return 0; }
}

fn main() i32
{
    c := new ImplementsIface2();
    return c.func2();
}
