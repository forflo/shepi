# Brainstorm

API:

echo foo | cmd1 arg1 arg2 arg3 | cmd2 arg1 arg2 arg3


command = {
    cmd = "cat",
    args = {"arg1", "arg2", ...}

    redir = {
        
    }
}

bp.sc() -- simple command: cmd

pipe = 
    bp.cmd("foo", "arg1", "arg2", ...) |
    bp.cmd("bar", "moo", ...) |


bp.echo(string) | bp.proc() | bp
