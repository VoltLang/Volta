module watt.io.monotonic;

import core.time : MonoTime;


@property long ticksPerSecond()
{
	return MonoTime.ticksPerSecond;
}

long ticks()
{
	return MonoTime.currTime().ticks;
}

public import core.time : convClockFreq;
