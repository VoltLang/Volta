module vls.build.build;

import core.rt.thread;

import io = watt.io;
import watt.path;
import watt.process.pipe;

/*!
 * Manages a single build.
 */
class Build
{
private:
	mBatteryPath: string;
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
		path := dirName(tomlPath);
		mConfigArgs = ["--chdir", path, "config", "--netboot", "."];
		mBuildArgs  = ["--chdir", path, "build"];
		mCompleted = false;
	}

	// Spawn the build. Blocks until completion.
	fn doBuild()
	{
		getOutput(mBatteryPath, mConfigArgs);
		mBuildOutput = getOutput(mBatteryPath, mBuildArgs);
		mCompleted = true;
		io.error.writeln(mBuildOutput);
		io.error.flush();
	}
}
