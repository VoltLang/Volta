module vls.build.build;

import core.rt.thread;

import io = watt.io;
import watt.conv;
import watt.path;
import watt.process.pipe;
import watt.text.string;

import ir = volta.ir;
import vls.server.responses;
import diagnostic = vls.server.diagnostic;
import vls.lsp;

/*!
 * Manages a single build.
 */
class Build
{
private:
	mBatteryPath: string;  //!< The path to the battery executable.
	mBatteryRoot: string;  //!< The path this build is run in.
	mConfigArgs:  string[];
	mBuildArgs:   string[];
	mThread: vrt_thread*;
	mCompleted: bool;
	mBuildOutput: string;

public:
	/*!
	 * Construct and run a build for the battery.toml file given.
	 *
	 * The build is performed asynchronously on a new thread.
	 */
	this(batteryPath: string, tomlPath: string)
	{
		setupBuild(batteryPath, tomlPath);
		mThread = vrt_thread_start_dg(doBuild);
	}

public:
	//! Has the build been launched?
	@property fn started() bool
	{
		return mThread !is null;
	}

	//! Has the build completed?
	@property fn completed() bool
	{
		return mCompleted;
	}

	//! What was the raw output of the build?
	@property fn output() string
	{
		return mBuildOutput;
	}

private:
	// Set the various internal variables that the build needs.
	fn setupBuild(batteryPath: string, tomlPath: string)
	{
		mBatteryPath = batteryPath;
		mBatteryRoot = dirName(tomlPath);
		mConfigArgs = ["--chdir", mBatteryRoot, "config", "--netboot", "."];
		mBuildArgs  = ["--chdir", mBatteryRoot, "build"];
		mCompleted = false;
	}

	// Spawn the build. Blocks until completion.
	fn doBuild()
	{
		retval: u32;
		mBuildOutput = getOutput(mBatteryPath, mBuildArgs, ref retval);
		if (retval != 0) {
			parseErrors();
		} else {
			diagnostic.clearBatteryRoot(mBatteryRoot);
		}
		/* Wait until the diagnostic thread has finished
		 * processing so the memory remains valid.
		 */
		diagnostic.blockUntilMessageProcessed();
		mCompleted = true;
	}

	fn parseErrors()
	{
		lines := splitLines(mBuildOutput);
		foreach (line; lines) {
			errorIndex := indexOf(line, Error);
			if (errorIndex <= 0) {
				continue;
			}
			locationSlice := strip(line[0 .. errorIndex]);
			locationComponents := split(locationSlice, ':');
			if (locationComponents.length < 3) {
				continue;
			}
			loc: ir.Location;
			loc.filename    = fullPath(locationComponents[0]);
			uri            := getUriFromPath(loc.filename);
			loc.line        = toUint(locationComponents[1]);
			loc.column      = toUint(locationComponents[2]);
			messageSlice   := strip(line[cast(size_t)errorIndex + Error.length .. $]);
			if (messageSlice.startsWith(": ")) {
				messageSlice = messageSlice[2 .. $];
			}
			if (messageSlice.endsWith(".")) {
				messageSlice = messageSlice[0 .. $-1];
			}
			diagnostic.addError(uri, ref loc, messageSlice, mBatteryRoot);
		}
	}
}

private:

enum Error = "error";
