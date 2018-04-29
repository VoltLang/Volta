//T requires:!x86
module main;

import core.rt.thread;

enum DatabaseSize = 100;
enum HalfDatabase = DatabaseSize / 2;
global sharedDatabase: i32[];
global sharedIndex:    size_t;
global dbMutex:        vrt_mutex*;
global threadOneHasLock: bool;

fn main() i32
{
	sharedDatabase = new i32[](DatabaseSize);
	dbMutex = vrt_mutex_new();
	scope (exit) vrt_mutex_delete(dbMutex);
	t1 := vrt_thread_start_fn(childThreadOne);
	while (!threadOneHasLock) {
	}
	t2 := vrt_thread_start_fn(childThreadTwo);
	vrt_thread_join(t2);
	vrt_thread_join(t1);
	return checkDatabase(1, 2);
}

fn childThreadOne()
{
	vrt_mutex_lock(dbMutex);
	threadOneHasLock = true;
	scope (exit) vrt_mutex_unlock(dbMutex);
	writeToDatabase(HalfDatabase, 1);
}

fn childThreadTwo()
{
	vrt_mutex_lock(dbMutex);
	scope (exit) vrt_mutex_unlock(dbMutex);
	writeToDatabase(HalfDatabase, 2);
}

fn checkDatabase(valueOne: i32, valueTwo: i32) i32
{
	for (i: size_t = 0; i < HalfDatabase; ++i) {
		if (sharedDatabase[i] != valueOne) {
			return 1;
		}
	}
	for (i: size_t = HalfDatabase; i < DatabaseSize; ++i) {
		if (sharedDatabase[i] != valueTwo) {
			return 2;
		}
	}
	return 0;
}

fn writeToDatabase(amount: size_t, value: i32)
{
	targetAmount := sharedIndex + amount;
	if (targetAmount > sharedDatabase.length) {
		targetAmount = sharedDatabase.length;
	}
	while (sharedIndex < targetAmount) {
		sharedDatabase[sharedIndex++] = value;
		/* Try to ensure that writes occur out of order
		 * if the mutex isn't working.
		 */
		vrt_sleep(1);
	}
}
