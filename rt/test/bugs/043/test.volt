//T compiles:yes
//T retval:1
module test;

class PipeFactory
{
	int pipesProduced;

	this(int initialPipes)
	{
		pipesProduced = initialPipes;
		return;
	}

	void produce(int amountOfPipes)
	{
		pipesProduced += amountOfPipes;
		return;
	}

	void produce(string orderString)
	{
		// The foreman can't read, so they just make one pipe.
		produce(1);
		return;
	}

	void produce()
	{
		produce("Dear sir/madam foreman. I require ten thousands pipes. This is VITAL.");
		return;
	}
}

int main()
{
	auto pipeFactory = new PipeFactory(0);
	pipeFactory.produce();
	return pipeFactory.pipesProduced;
}

