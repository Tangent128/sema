Sema Scripting Reference
========================

Sema is controlled by Lua scripts; indeed, architecture-wise, it is little more than a Lua script server. Each script gets its own independent global environment.

Scripts are identified by their absolute filepaths, and sema will only load one copy of a script at a time. Symlinks are *not* followed, and so multiple symlinks to the same script are considered as separate instances and can be run in parallel. (this behavior *may* change in the future)

Scripts may have parallel threads of execution, which are implemented with coroutines.


Command Handlers
----------------

When a command is sent to a script, it is looked up in the script's global "command" table; the command's arguments will be passed to any function found. As such, a custom command can be defined in a straightforward manner:

```lua
function command.echoSwapped(a, b)
	reply(b, a)
end
```

And invoked like so:

`sema scriptName echoSwapped first second`

Three commands have default implementations:
* `up` - set the "up" event
* `down` - unset the "up" event and SIGTERM any child process running on the initial thread
* `status` - default command if none given

Command handlers are invoked on independent threads.

without further ado,


Scripting API
-------------

Sema scripts have access to the following standard Lua functions/constants:
* assert
* error
* ipairs
* next
* pairs
* pcall
* select
* setmetatable
* tonumber
* tostring
* type
* _VERSION
* table.*
* string.*
* math.*
* bit32.*

Outside standard stuff:


### Utility Functions

`scriptName()`

Returns the full path of the running script file.

`fullpath(name)`

Returns an absolute (though non-canonicalized) path to the given filename, taken to be relative to the directory containing the current script.

`reply(...)`

Must be called from a command handler. Sends its arguments back to the client.

`parallel(func)`

Executes `func` on a new coroutine, and returns a handle that can be used for signals.


### Process Spawning and Control

`run{...}` **(blocking)**

Spawn a child process, and wait for it to terminate. The positional indices of the table give the command and arguments, while some named parameters may be defined:
* `.stdin`,`.stdout`,`.stderr` - remap input/output to pipes
* `.chdir` - change to the given directory instead of running in the directory containing the current script (must exist)
* `.user` - run under another UID; may be a string for a username or a number for a direct UID. Requires root privileges to work, obviously.

`runIfUp{...}` **(blocking)**

Equivalent to `waitEvent "up"; run{...}`

`cmd "string"`

Utility function, splits the given string on whitespace and multi-returns all the pieces. Can help make "simple" command lines look nicer.

`signal(threadHandle, SIGNAL)`

If the given thread (returned from `parallel()`) is waiting on a child process, send SIGNAL to that process. Global constants `SIGALRM`, `SIGCHLD`, `SIGHUP`, `SIGINT`, `SIGKILL`, `SIGPIPE`, `SIGTERM`, `SIGUSR1`, and `SIGUSR2` are defined.

If `threadHandle` is nil, it targets the initial "main" thread.


### Pipelines

`pipe()`

Creates a pipe, then returns a table with `.input` and `.output` fields representing each end. These ends may be passed to the `.stdin`, etc, arguments to `run{...}`, and can be used to pipeline processes together.

`pipe().input.write(str)`

Writes `str` to the pipe; useful for controlling game servers that read commands from stdin.

`pipe().input.writeln(str)`

Convenience function; like `.write`, but appends a newline after `str`.


### Events

Events can be used to synchronize the actions of parallel threads; for instance, to ensure a backup command will wait for a daemon to go down.

An event may be "triggered", in which case any threads waiting for it at that moment may resume. An event may also be "set", in which case future attempts to wait on it will immediately resume. The string "up" is set by default for each script.

An event can be identified by any non-nil value; strings are probably the clearest.

`waitEvent(event)`

If `event` is not "set", then block the current thread until `event` is triggered or set.

`triggerEvent(event)`

Wake up threads waiting on `event`.

`setEvent(event, on)`

If `on` is true or nil, set `event`; if `on` is false, unset `event`.


Considerations
--------------

* Since threads are implemented via coroutines, they must yield to allow other threads and scripts a chance to run. `waitEvent(...)` will sometimes block, but not if the event is set; `run{...}` and `runIfUp{...}` are currently the only reliable blocking functions, and are annotated as such above.

