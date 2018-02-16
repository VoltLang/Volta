// Just enough to start and join a thread.
module core.c.pthread;
extern (C):

import core.c.config;

alias pthread_t = c_ulong;

fn pthread_create(pthread_t*, void*, fn(void*) void*, void*) i32;
fn pthread_join(pthread_t, void*) i32;
