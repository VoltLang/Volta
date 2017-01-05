module test;

fn toString(i: i32) string
{
	return "42";
}

class Player
{
	name: string;
	health: i32;

	this(name: string, health: i32)
	{
		this.name = name;
		this.health = health;
		return;
	}

	fn healthString() string
	{
		return .toString(health);
	}
}

fn main() i32
{
	player := new Player("Bernard", 1);
	s: string = player.healthString();
	return 0;
}

