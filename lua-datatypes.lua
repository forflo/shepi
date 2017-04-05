local posix = require("posix")
local datatypes = {}

datatypes.types = {Command = {}, Pipe = {}}

local function pipeopen(path, ...)
    local r1, stdin = posix.pipe()
    local stdout, w2 = posix.pipe()
    local stderr, w3 = posix.pipe()
    assert((stdin ~= nil and stdout ~= nil and stderr ~= nil),
        "pipe() failed")
    local pid, err = posix.fork()
    assert(pid ~= nil, "fork() failed")
    if pid == 0 then
        posix.close(stdin)
        posix.close(stdout)
        posix.close(stderr)
        posix.dup2(r1, posix.fileno(io.stdin))
        posix.dup2(w2, posix.fileno(io.stdout))
        posix.dup2(w3, posix.fileno(io.stderr))
        local ret, err = posix.execp(path, ...)
        assert(ret ~= nil, "execp() failed")
        posix._exit(1)
        return
    end
    posix.close(r1)
    posix.close(w2)
    posix.close(w3)
    return pid, stdin, stdout, stderr
end

--local function popen3(program, ...)
--    local pid, sin, sout, serr = pipeopen(program, ...)
--    local infile, outfile, errfile =
--        posix.fdopen(sin, "w"), posix.fdopen(sout, "r"), posix.fdopen(serr, "r")
--    return infile, outfile, errfile
--end

-- Datastructures
function datatypes.Command(program, ...)
    local mtab = {}
    mtab.__call = function(callee, str)
        return callee:execute(str)
    end
    local t = {}
    t._type = datatypes.types.Command
    t._program = program
    t._arguments = table.pack(...)
    function t:getType() return self._type end
    function t:getArguments() return self._arguments end
    function t:getProgram() return self._program end
    function t:execute(argfd)
        local pid, infd, outfd, errfd =
            pipeopen(self:getProgram(),
                     table.unpack(self:getArguments()))
        posix.dup2(argfd, infd)
        return outfd, errfd, pid
    end
    setmetatable(t, mtab)
    return t
end

function datatypes.Pipe(left, right)
    local mtab = {}
    local t = {}
    t._left = left
    t._right = right
    t._pids = {}
    t._type = datatypes.types.Pipe

    function t:getLeft() return self._left end
    function t:getRight() return self._right end
    function t:getPids() return self._pids end
    function t:getType() return self._type end
    function t:setPids(v) self._pids = v end

    function t:waitPids()
        -- recursively wait for all pids
        if self._left:getType() == datatypes.types.Pipe then
            self._left:waitPids()
        end
        if self._right:getType() == datatypes.types.Pipe then
            self._right:waitPids()
        end
        for _, pid in self._pids do
            posix.wait(pid)
        end
    end

    mtab.__call = function(callee, infd)
        local leftSout, leftEout, leftPid = callee:getLeft()(infd)
        local rightSout, rightEout, rightPid = callee:getRight()(leftSout)
        callee:setPids{leftPid, rightPid}
        return rightSout, rightEout, rightPid
    end
    setmetatable(t, mtab)
    return t
end

return datatypes
