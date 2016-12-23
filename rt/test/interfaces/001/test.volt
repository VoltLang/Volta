//T compiles:yes
//T retval:66
module test;

interface ICreature {
	int hp();
}

interface IFloatGetter {
	int getInt(float x);
}

interface IGetTwo {
	int getTwo();
}

interface IIntGetter : IFloatGetter, IGetTwo {
	int getInt(int x);
}

class Player : ICreature, IIntGetter {
	override int hp() { return 31; }
	override int getInt(int x) { return x; }
	override int getInt(float x) { return cast(int)x; }
	override int getTwo() { return 2; }
	string name() { return "Jakob"; }
}

int proxy(ICreature a, IFloatGetter b, IGetTwo c) {
	Player p = cast(Player) b;
	assert(p !is null);
	return a.hp() + b.getInt(1.0f) + c.getTwo();
}

int main() {
	auto player = new Player();
	ICreature a = player;
	IIntGetter b = player;
	return b.getInt(32) + proxy(a, player, player);
}
