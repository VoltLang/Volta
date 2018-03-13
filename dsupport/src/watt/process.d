module watt.process;

public import std.process : wait, Pid;
public import std.process : dspawnProcess = spawnProcess;


Pid spawnProcess(string cmd, string[] args)
{
	string[] a = [cmd];
	foreach (arg; args) {
		a ~= arg;
	}
	return dspawnProcess(a);
}
