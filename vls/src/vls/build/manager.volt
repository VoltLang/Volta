module vls.build.manager;

import core.rt.thread;

import watt = [watt.io, watt.path, watt.text.path, watt.text.string, watt.http];
import file = watt.io.file;
import semver = watt.text.semver;

//! The directory in which the battery executable exists.
enum BatteryBin    = "batteryBin";
//! Battery executables that we download will start with this.
enum BatteryPrefix = "battery-";
version (Windows) {
	enum BatteryEnd = ".exe";
}

/*!
 * Handles the build environment.
 *
 * Manager is in charge of retrieving battery,
 * and launching battery.
 */
class Manager
{
public:
	//! The extensions install folder's root.
	extensionPath: string;

private:
	mSetupThread: vrt_thread*;
	//! Temporary for netget.
	mBatteryPath: string;

public:
	/*!
	 * Construct a new Manager.
	 *
	 * Launches a new thread that calls `setupEnvironment`.
	 */
	this(extensionPath: string)
	{
		this.extensionPath = extensionPath;
		mBatteryPath = watt.concatenatePath(extensionPath, "battery-netget.exe");
		if (!watt.exists(mBatteryPath)) {
			mSetupThread = vrt_thread_start_dg(setupEnvironment);
		}
	}

public:
	/*!
	 * Attempt to download battery.
	 */
	fn setupEnvironment()
	{
		http := new watt.Http();
		req  := new watt.Request(http);
		req.server = "github.com";
		req.url    = "/VoltLang/Toolchain/blob/master/battery-netget.exe";
		req.port   = 443;
		req.secure = true;

		http.loop();
		if (!req.errorGenerated()) {
			file.write(req.getData(), mBatteryPath);
		}
	}

	/*!
	 * Try and get the latest version of battery available.
	 *
	 * Use the internet to get the latest battery version.
	 * Returns true and fills out `ver` if successful, otherwise
	 * false is returned and `ver` is invalid.
	 */
	fn latestBatteryVersion(out ver: semver.Release) bool
	{
		return false;
	}

	/*!
	 * If a battery of `ver` version would exist, return the path it would have.
	 */
	fn proposedBatteryPath(ver: semver.Release) string
	{
		baseName := new "${BatteryPrefix}${ver}";
		base := watt.concatenatePath(extensionPath, baseName);
		version (Windows) {
			return new "${base}${BatteryEnd}";
		} else {
			return base;
		}
	}

	/*!
	 * Get the version of a battery executable path,
	 * or null if we couldn't determine it.
	 */
	fn batteryVersion(path: string) semver.Release
	{
		filename := watt.baseName(path);
		version (Windows) {
			if (watt.endsWith(filename, BatteryEnd)) {
				filename = filename[0 .. $-BatteryEnd.length];
			}
		}
		if (!watt.startsWith(filename, BatteryPrefix) ){
			return null;
		}
		filename = filename[BatteryPrefix.length .. $];
		if (!semver.Release.isValid(filename)) {
			return null;
		}
		return new semver.Release(filename);
	}

	/*!
	 * Is battery installed?
	 *
	 * If this install of VLS has a valid battery executable installed,
	 * return true and fill out `path` and `ver`.  
	 * Otherwise, return false, and `path` and `ver` are invalid.
	 */
	fn installedBattery(out path: string, out ver: semver.Release) bool
	{
		binPath := watt.concatenatePath(extensionPath, BatteryBin);
		if (!file.isDir(binPath)) {
			return false;
		}

		fn hit(s: string) file.SearchStatus {
			if (watt.startsWith(s, BatteryPrefix)) {
			}
			return file.SearchStatus.Continue;
		}

		file.searchDir(binPath, "*", hit);

		return false;
	}
}
