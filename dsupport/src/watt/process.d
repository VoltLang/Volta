module watt.process;

import std.process : wait, Pid;
import std.process : dspawnProcess = spawnProcess;


Pid spawnProcess(string cmd, string[] args)
{
	string[] a = [cmd];
	foreach (arg; args) {
		a ~= arg;
	}
	return dspawnProcess(a);
}
