/*!
 * You approach the small yet mildly intricate module with apprehension.  
 * Rubbing your hand against it, you remark out loud to no one in particular
 *   "This module is puzzling. Why does it exist? Why not simply handle the
 *    requests as they come in, one by one?"
 * That's when you notice the small brass plate affixed to the module,
 * with a simple title in neat block capitals
 *
 *   "JUSTIFICATION"
 *
 * You continue to read.
 *
 *   "The message for signatureHelp and the didChange notification that
 *   triggered the aforementioned come in simultaneously. Due to the nature
 *   of node.js, vscode cannot dictate the order in which they arrive. But
 *   to correctly handle them, we need them to occur in a particular order;
 *   change, then signatureHelp. That way we can see if the user has typed
 *   ')', and respond appropriately."
 *
 * You leave the module be. There is no call for poking around with the
 * innards of this module for no good reason. While walking away, you
 * turn around with a start. Did the module... snarl at you?
 */
module vls.messageHopper;

import io         = watt.io;
import core       = core.rt.thread;
import containers = watt.containers.queue;
import monotonic  = watt.io.monotonic;

import lsp = vls.lsp;

fn add(ro: lsp.RequestObject)
{
	req: Request;
	req.object    = ro;
	req.timestamp = monotonic.convClockFreq(monotonic.ticks(), monotonic.ticksPerSecond, 1000);
	gHopper.enqueue(req);
}

fn process(handle: dg(lsp.RequestObject) bool)
{
	while (gHopper.length != 0) {
		latestMessage := gHopper.peek();
		switch (latestMessage.object.methodName) {
		case "textDocument/signatureHelp":
			if (!gDelaying && gHopper.length == 1) {
				if (latestMessage.timestamp - gLastChange < SleepTime) {
					goto default;
				} else {
					gDelaying = true;
					return longSleep();
				}
			} else if (gHopper.length >= 2) {
				tryToReverse(handle);
				gDelaying = false;
				break;
			} else if (gDelaying) {
				gDelaying = false;
			}
			goto default;
		case "textDocument/didChange":
			gLastChange = latestMessage.timestamp;
			goto default;
		default:
			gHopper.dequeue();
			handle(latestMessage.object);
			break;
		}
	}

	return shortSleep();
}

private:

enum SleepTime = 5;  // In milliseconds.

struct Request
{
	object:    lsp.RequestObject;
	timestamp: i64;
}

struct RequestQueue = mixin containers.Queue!Request;

global gHopper:     RequestQueue;
global gLastChange: i64;
global gDelaying:   bool;

fn shortSleep()
{
	core.vrt_sleep(1);
}

fn longSleep()
{
	core.vrt_sleep(SleepTime);
}

fn tryToReverse(handle: dg(lsp.RequestObject) bool) bool
{
	assert(gHopper.length >= 2);
	a := gHopper.dequeue();
	b := gHopper.dequeue();
	if (a.object.methodName == "textDocument/signatureHelp" &&
		b.object.methodName == "textDocument/didChange") {
		handle(b.object);
		handle(a.object);
		return true;
	} else {
		handle(a.object);
		handle(b.object);
		return false;
	}
}
