//T compiles:yes
//T retval:41
module test;

class Monster
{
	int hp;

	this(int hp)
	{
		this.hp = hp;
	}

	void restore(int amount)
	{
		hp += amount * 2;
	}
}

void damage(Monster monster, int amount)
{
	monster.hp -= amount;
}

void restore(Monster monster, int amount)
{
	monster.hp += amount;
}

int triple(int i)
{
	return i * 3;
}

int main()
{
	auto monster = new Monster(50);
	damage(monster, 8);
	monster.damage(8);
	monster.restore(2);
	int one = 1;
	return monster.hp + one.triple();
}
