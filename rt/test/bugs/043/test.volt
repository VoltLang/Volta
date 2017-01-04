module test;

class PipeFactory
{
	pipesProduced: i32;

	this(initialPipes: i32)
	{
		pipesProduced = initialPipes;
		return;
	}

	fn produce(amountOfPipes: i32)
	{
		pipesProduced += amountOfPipes;
		return;
	}

	fn produce(orderString: string)
	{
		// The foreman can't read, so they just make one pipe.
		produce(1);
		return;
	}

	fn produce()
	{
		produce("Dear sir/madam foreman. I require ten thousands pipes. This is VITAL.");
		return;
	}
}

fn main() i32
{
	pipeFactory := new PipeFactory(0);
	pipeFactory.produce();
	return pipeFactory.pipesProduced - 1;
}

