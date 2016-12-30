module test;

interface ICreature
{
	fn hp() i32;
}

interface IFloatGetter
{
	fn getInt(x: f32) i32;
}

interface IGetTwo
{
	fn getTwo() i32;
}

interface IIntGetter : IFloatGetter, IGetTwo
{
	fn getInt(x: i32) i32;
}

class Player : ICreature, IIntGetter
{
	override fn hp() i32 { return 31; }
	override fn getInt(x: i32) i32 { return x; }
	override fn getInt(x: f32) i32 { return cast(i32)x; }
	override fn getTwo() i32 { return 2; }
	string name() { return "Jakob"; }
}

fn proxy(a: ICreature, b: IFloatGetter, c: IGetTwo) i32 
{
	p: Player = cast(Player) b;
	assert(p !is null);
	return a.hp() + b.getInt(1.0f) + c.getTwo();
}

fn main() i32
{
	player := new Player();
	a: ICreature = player;
	b: IIntGetter = player;
	return (b.getInt(32) + proxy(a, player, player)) == 66 ? 0 : 1;
}

