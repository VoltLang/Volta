//T compiles:yes
//T retval:0
module test;

string toString(int i)
{
	return "42";
}

class Player
{
	string name;
	int health;

	this(string name, int health)
	{
		this.name = name;
		this.health = health;
		return;
	}

	string healthString()
	{
		return .toString(health);
	}
}

int main()
{
	auto player = new Player("Bernard", 1);
	string s = player.healthString();
	return 0;
}

