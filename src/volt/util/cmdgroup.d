// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/battery/license.d (BOOST ver. 1.0).
module volt.util.cmdgroup;

version (Volt) {

	import core.c.stdio : FILE, fileno, stdin, stdout, stderr;
	import core.exception;

	version (Windows) {
		import core.c.windows.windows : HANDLE, DWORD, FALSE,
			GetLastError, WaitForMultipleObjects,
			GetExitCodeProcess, CloseHandle, GetLastError;
	} else {
		import core.c.posix.sys.types : pid_t;
	}

	import watt.process : Pid, spawnProcess, waitManyPosix;

	alias OsHandle = Pid.OsHandle;

} else {

	import std.process : Pid, spawnProcess;
	import std.format : format;

	version (Windows) {
		import core.sys.windows.windows : HANDLE, DWORD, FALSE,
			GetLastError, WaitForMultipleObjects,
			GetExitCodeProcess, CloseHandle, GetLastError;
		alias OsHandle = HANDLE;
	} else {
		import core.sys.posix.sys.wait : waitpid;
		import core.sys.posix.sys.types : pid_t;
		alias OsHandle = pid_t;
	}

}

import watt.text.format : format;
import watt.conv : toString;


/*!
 * Helper class to launch one or more processes
 * to run along side the main process.
 */
class CmdGroup
{
public:
	alias DoneDg = void delegate(int);  // Is called with the retval of the completed command.


private:
	Cmd[] cmdStore;

	//! Environment to launch all processes in.
	//Environment env;

	//! For Windows waitOne, to avoid unneeded allocations.
	version (Windows) OsHandle[] __handles;

	//! Number of simultanious jobs.
	uint maxWaiting;

	//! Number of running jobs at this moment.
	uint waiting;

	/*!
	 * Small container representing a executed command, is recycled.
	 */
	static class Cmd
	{
	public:
		//! Executable.
		string cmd;

		//! Arguments to be passed.
		string[] args;

		//! Called when command has completed.
		DoneDg done;

		//! System specific process handle.
		OsHandle handle;

		//! In use.
		bool used;


	public:
		/*!
		 * Initialize all the fields.
		 */
		void set(string cmd, string[] args, DoneDg dgt,
		         OsHandle handle)
		{
			used = true;
			this.cmd = cmd;
			this.args = args;
			this.done = dgt;
			this.handle = handle;
		}

		/*!
		 * Reset to a unused state.
		 */
		void reset()
		{
			used = false;
			cmd = null;
			args = null;
			done = null;
			version (Windows) {
				handle = null;
			} else {
				handle = 0;
			}
		}
	}

public:
	this(uint maxWaiting)
	{
		//this.env = env;
		this.maxWaiting = maxWaiting;

		cmdStore = new Cmd[](maxWaiting);
		version (Windows) __handles = new OsHandle[](maxWaiting);

		foreach (ref cmd; cmdStore) {
			cmd = new Cmd();
		}
	}

	void run(string cmd, string[] args, DoneDg dgt)
	{
		// Wait until we have a free slot.
		while (waiting >= maxWaiting) {
			waitOne();
		}

		version (Volt) {
			auto pid = spawnProcess(cmd, args);
		} else {
			auto pid = spawnProcess(cmd ~ args);
		}

		version (Windows) {

			newCmd(cmd, args, dgt, pid.osHandle);
			waiting++;

		} else version(Posix) {

			newCmd(cmd, args, dgt, pid.osHandle);
			waiting++;

		} else {
			static assert(false);
		}
	}

	void waitOne()
	{
		version(Windows) {
			uint hCount;
			foreach (cmd; cmdStore) {
				if (cmd.used) {
					__handles[hCount++] = cmd.handle;
				}
			}

			// If no cmds running just return.
			if (hCount == 0) {
				return;
			}

			auto ptr = __handles.ptr;
			auto uRet = WaitForMultipleObjects(hCount, ptr, FALSE, cast(uint)-1);
			if (uRet == cast(DWORD)-1 || uRet >= hCount) {
				throw new Exception("Wait failed with error code " ~ .toString(cast(int)GetLastError()));
			}

			auto hProcess = __handles[uRet];

			// Retrieve the command for the returned wait, and remove it from the lists.
			Cmd c;
			foreach (cmd; cmdStore) {
				if (hProcess !is cmd.handle) {
					continue;
				}
				c = cmd;
				break;
			}

			int result = -1;
			auto bRet = GetExitCodeProcess(hProcess, cast(uint*)&result);
			auto cRet = CloseHandle(hProcess);
			if (bRet == 0) {
				c.reset();
				throw new CmdException(c.cmd, c.args,
					"abnormal application termination");
			}
			if (cRet == 0) {
				throw new Exception("CloseHandle failed with error code " ~ .toString(cast(int)GetLastError()));
			}

		} else version(Posix) {

			int result;
			pid_t pid;

			if (waiting == 0) {
				return;
			}

			Cmd c;
			// Because stopped processes doesn't count.
			while(true) {
				result = waitManyPosix(pid);

				bool foundPid;
				foreach (cmd; cmdStore) {
					if (cmd.handle != pid) {
						continue;
					}

					c = cmd;
					foundPid = true;
					break;
				}

				if (foundPid) {
					break;
				}

				if (pid > 0) {
					throw new Exception("PID waited on but not cleared!\n");
				}
				continue;
			}
		} else {
			static assert(false);
		}

		// But also reset it before calling the dgt
		auto dgt = c.done;

		c.reset();
		waiting--;

		if ((dgt !is null)) {
			dgt(result);
		}
	}

	void waitAll()
	{
		while(waiting > 0) {
			waitOne();
		}
	}

private:
	Cmd newCmd(string cmd, string[] args, DoneDg dgt, OsHandle handle)
	{
		foreach (c; cmdStore) {
			if (c is null) {
				throw new Exception("null cmdStore.");
			}
			if (!c.used) {
				c.set(cmd, args, dgt, handle);
				return c;
			}
		}
		throw new Exception("newCmd failure");
	}
}

/*!
 * Exception form and when execquting commands.
 */
class CmdException : Exception
{
	this(string cmd, string[] args, string reason)
	{
		auto err = format("The below command failed due to: %s\n%s %s", reason, cmd, args);
		super(err);
	}
}

version (D_Version2)
{
	version (Posix)
	{
		bool stopped(int status) { return (status & 0xff) == 0x7f; }
		bool signaled(int status) { return ((((status & 0x7f) + 1) & 0xff) >> 1) > 0; }
		bool exited(int status) { return (status & 0x7f) == 0; }

		int termsig(int status) { return status & 0x7f; }
		int exitstatus(int status) { return (status & 0xff00) >> 8; }

		int waitManyPosix(out pid_t pid)
		{
			int status, result;

			// Because stopped processes doesn't count.
			while(true) {
				pid = waitpid(-1, &status, 0);

				if (exited(status)) {
					result = exitstatus(status);
				} else if (signaled(status)) {
					result = -termsig(status);
				} else if (stopped(status)) {
					continue;
				} else {
					result = -1; // TODO errno
				}

				return result;
			}
			assert(false);
		}
	}
}
