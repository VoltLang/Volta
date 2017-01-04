module test;

class Monster
{
	hp: i32;

	this(hp: i32)
	{
		this.hp = hp;
	}

	fn restore(amount: i32)
	{
		hp += amount * 2;
	}
}

fn damage(monster: Monster, amount: i32)
{
	monster.hp -= amount;
}

fn restore(monster: Monster, amount: i32)
{
	monster.hp += amount;
}

fn triple(i: i32) i32
{
	return i * 3;
}

fn main() i32
{
	monster := new Monster(50);
	damage(monster, 8);
	monster.damage(8);
	monster.restore(2);
	one: i32 = 1;
	return monster.hp + one.triple() - 41;
}
