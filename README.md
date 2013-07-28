Sema
====

A Lua-scripted daemon management service.

What is Sema?
-------------

`sema` is a **se**rvice **ma**nager written in Lua and C.

It is designed to serve the same general role as initd, upstart or systemd, while drawing additional inspiration from daemontools and runit.

A `sema` server daemon supervises multiple services under the direction of Lua scripts, which can receive custom commands from client commands. A client can also auto-spawn a server if none is currently running.

The project's git repository and bug tracker may be found at
https://github.com/Tangent128/sema
  

Building
--------

`sema` uses the [Redo] build system; however, installing `redo` is not necessary, as a minimal always-rebuilds implementation is included under `src/do.sh`.
[Redo]: https://github.com/apenwarr/redo

Building the embedded Lua interpreter requires the standard `make` utility.

From the root of the repository, run:

`src/do.sh sema`

or

`redo sema`

as appropriate; the resulting "sema" executable may be installed where desired.

If not using GCC: CC & LD variables may be set in a file named `config`, with standard shell syntax.

Usage
-----

`./sema --server`

Launch a foreground server process, which can receive commands
from future clients.


`./sema --client scriptFile.sema [command [args...]]`

Connect to the server and ensure the script 'scriptFile.sema'
is running; optionally send command and arguments to the script.


`./sema scriptFile.sema [command [args...]]`

Like --client, but automatically spawn a background server if
a server is not yet running.


`./sema --ls`

List the server's currently loaded scripts, and PIDs of any daemons.

	
`./sema --kill scriptFile.sema`

Force-quit a script on the server and SIGKILL its daemons.


Scripts
-------

A simple `sema` script for supervising and controlling SSHD:

```lua
#!/path/to/sema
-- The above shabang line is useful if you mark your control scripts executable

-- define a custom command
function command.reloadConfig()
	signal(nil, SIGHUP)
end

-- "up" and "down" have default implementations

while true do
	runIfUp{
		cmd "/usr/sbin/sshd -D"
	}
end
```

For fuller documentation of the script API, see `SCRIPTING` and the files under `example/`


Environment
-----------

The control socket for the client and server to use may be specified by the $SEMA_SOCKET environment variable.

Otherwise, the default socket location depends on the current user; if running as root, then `/run/sema.socket` will be used.

If running as an ordinary user, `$XDG_RUNTIME_DIR/sema.socket` and `$HOME/.sema.socket` will be tried, in that order.


License
-------

`sema` is MIT-licensed, like Lua.

For the full license read `COPYRIGHT`.

