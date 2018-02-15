/*!
 * Code to create and manage the diagnostic worker thread.
 *
 * Multiple threads want to report errors, we need a unified list.
 * To ensure sanity (race conditions, GC memory going missing underneath us)
 * only one thread, this one, is permitted to write to a global
 * diagnostic.Manager instance at a time.
 *
 * This module contains methods that calling code should use that submits
 * work requests to the worker thread, which will be processed in time.
 */
module vls.server.diagnostic.thread;

import core.rt.thread;

import ir = volta.ir;
import lsp = vls.lsp;
import vls.server.diagnostic.diagnostic;
import vls.server.diagnostic.manager;

global this()
{
	mutex = vrt_mutex_new();
	thandle = vrt_thread_start_fn(threadFunction);
}

global ~this()
{
	m: Message;
	m.type = Message.Type.Quit;
	addMessage(m);
	vrt_thread_join(thandle);
	vrt_mutex_delete(mutex);
}

//! Generate an error.
fn addError(uri: string, ref in loc: ir.Location, message: string, batteryRoot: string = null)
{
	addDiagnostic(uri, ref loc, message, batteryRoot, lsp.DIAGNOSTIC_ERROR);
}

//! Generate a warning.
fn addWarning(uri: string, ref in loc: ir.Location, message: string, batteryRoot: string = null)
{
	addDiagnostic(uri, ref loc, message, batteryRoot, lsp.DIAGNOSTIC_WARNING);
}

//! Clear all messages associated with uri and no battery root.
fn clearUri(uri: string)
{
	m: Message;
	m.type = Message.Type.ClearUri;
	m.stringArgument = uri;
	addMessage(m);
}

//! Clear all messages associated with the given battery root, or with no root.
fn clearBatteryRoot(batteryRoot: string)
{
	m: Message;
	m.type = Message.Type.ClearBatteryRoot;
	m.stringArgument = batteryRoot;
	addMessage(m);
}

/*!
 * Block until there's no message pending.
 * 
 * If this is called after a message has been added,
 * the message added will be processed when this returns.
 * You may be waiting a little longer than needed
 * (For instance, the job completes, a new job starts,
 * you call this, you end up waiting for the new job
 * to finish), but it won't underwait, which is what
 * we want to avoid.
 */
fn blockUntilMessageProcessed()
{
	while (messageWaiting) {
		vrt_sleep(100);
	}
}

private:

/* Add the given information to a NewDiagnostic Message.
 */
fn addDiagnostic(uri: string, ref in loc: ir.Location, message: string, batteryRoot: string, level: i32)
{
	m: Message;
	m.type = Message.Type.NewDiagnostic;
	m.diagnostic.uri = uri;
	m.diagnostic.loc = loc;
	m.diagnostic.message = message;
	m.diagnostic.batteryRoot = batteryRoot;
	m.diagnostic.level = level;
	addMessage(m);
}

/* A message packet, tells the worker thread what to tell the Manager to do.
 */
struct Message
{
	enum Type
	{
		/* Add a new diagnostic.
		 */
		NewDiagnostic,
		/* Remove any errors associated with the given uri,
		 * and not associated with a battery root.
		 */
		ClearUri,
		/* Remove any errors associated with a given battery root,
		 * or associated with no battery root.
		 */
		ClearBatteryRoot,
		/* The worker thread will terminate, leaving any additional work
		 * undone.
		 */
		Quit
	}

	type: Type;              // The exact type of message this contains.
	diagnostic: Diagnostic;  // If this is a NewDiagnostic message, the Diagnostic to add.
	stringArgument: string;  // If this is a Clear* message, the uri or batteryRoot to clear.
}

global mutex:   vrt_mutex*;   // Handles access to `message`, `messageWaiting`.
global thandle: vrt_thread*;  // The actual handle to the worker thread.
global message: Message;      // The message for the Manager to process.
global messageWaiting: bool;  // Is there a message waiting?
global manager: Manager;      // Only the worker thread should touch this.

/* The main loop of the worker thread.
 */
fn threadFunction()
{
	manager = new Manager();
	running := true;
	while (running) {
		blockUntilMessageArrives();
		vrt_mutex_lock(mutex);
		msg := message;
		dispatchMessage(msg, ref running);
		messageWaiting = false;
		vrt_mutex_unlock(mutex);
	}
}

/* Return when we have messages.
 */
fn blockUntilMessageArrives()
{
	while (!messageWaiting) {
		vrt_sleep(100);
	}
}

/* Add a message to be processed.
 * The memory behind msg must remain valid until task completion.
 */
fn addMessage(msg: Message)
{
	blockUntilMessageProcessed();
	vrt_mutex_lock(mutex);
	scope (exit) vrt_mutex_unlock(mutex);
	message = msg;
	messageWaiting = true;
}

/* Intepret the given message and issue commands to the manager.
 */
fn dispatchMessage(message: Message, ref running: bool)
{
	final switch (message.type) with (Message.Type) {
	case Quit:
		running = false;
		break;
	case NewDiagnostic:
		manager.addDiagnostic(message.diagnostic);
		break;
	case ClearUri:
		manager.clearUri(message.stringArgument);
		break;
	case ClearBatteryRoot:
		manager.clearBatteryRoot(message.stringArgument);
		break;
	}
}
