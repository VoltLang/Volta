//T macro:warnings
//T check:assigning x to itself
//T check:assigning cnghbisnbtltopitbh to itself
module test;

class ClassNameGoesHereButItShouldNotBeTooLongThisOneProbablyIsToBeHonest
{
	x: i32;

	this(/*x: i32 let's just remove this for now*/)
	{
		this.x = x;  // oh no!
	}
}

fn main() i32
{
	cnghbisnbtltopitbh := new ClassNameGoesHereButItShouldNotBeTooLongThisOneProbablyIsToBeHonest();
	cnghbisnbtltopitbh = cnghbisnbtltopitbh;
	return 0;
}
