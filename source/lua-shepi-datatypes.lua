local posix = require("posix")
local datatypes = {}

-- "fat enums"
datatypes.types = { COMMAND = {1}, PIPE = {2}, FORK = {3}, FUN = {4} }

local function pipeopen(argfd, path, ...)
    local r2, w2 = posix.pipe()
    local r3, w3 = posix.pipe()
    assert((r2 ~= nil and r3 ~= nil), "pipe() failed")
    local pid, err = posix.fork()
    assert(pid ~= nil, "fork() failed")
    if pid == 0 then
        posix.close(r2)
        posix.close(r3)
        posix.dup2(argfd, posix.fileno(io.stdin))
        posix.dup2(w2, posix.fileno(io.stdout))
        posix.dup2(w3, posix.fileno(io.stderr))
        local ret, err = posix.execp(path, ...)
        assert(ret ~= nil, "execp() failed")
        posix._exit(1)
        return
    end
    posix.close(w2)
    posix.close(w3)
    return r2, r3, pid
end

local function pipeopenFun(argfd, func)
    local r2, w2 = posix.pipe()
    local r3, w3 = posix.pipe()
    assert((r2 ~= nil and r3 ~= nil), "pipe() failed")
    local pid, err = posix.fork()
    assert(pid ~= nil, "fork() failed")
    if pid == 0 then
        local stdin = posix.fdopen(argfd, "r")
        local stdout = posix.fdopen(w2, "w")
        local stderr = posix.fdopen(w3, "w")
        posix.close(r2)
        posix.close(r3)
        func(stdin, stdout, stderr)
        stdin:close()
        stdout:close()
        stderr:close()
        posix._exit(1)
        return
    end
    posix.close(w2)
    posix.close(w3)
    return r2, r3, pid
end

function datatypes.SyncFork(...)
    local t = {}
    local mtab = {}
    mtab.__call = function(callee, fd) return callee:execute(fd) end
    t._pipes = table.pack(...)
    t._pid = nil
    t._type = datatypes.types.FORK
    function t:setPid(v) self._pid = v end
    function t:getPid() return self._pid end
    function t:waitPids()
        posix.wait(self:getPid())
    end
    function t:getPipes() return self._pipes end
    function t:getType() return self._type end
    function t:execute(fd)
        local out, err, pid = pipeopenFun(
            fd,
            function(stdin, stdout, stderr)
                local allPrev = stdin:read("a")
                for _, pipe in ipairs(self:getPipes()) do
                    local read, write = posix.pipe()
                    local writeTf = posix.fdopen(write, "w")
                    writeTf:write(allPrev)
                    writeTf:close()
                    local outFd, errFd, pid = pipe(read)
                    pipe:waitPids()
                    local errFdTf = posix.fdopen(errFd, "r")
                    local outFdTf = posix.fdopen(outFd, "r")
                    stdout:write(outFdTf:read("a"))
                    stderr:write(errFdTf:read("a"))
                end
            end)
        self:setPid(pid)
        return out, err, pid
    end
    setmetatable(t, mtab)
    return t
end

function datatypes.Fun(fun)
    local t = {}
    local mtab = {}
    mtab.__call = function(callee, fd)
        return callee:execute(fd)
    end
    t._pid = nil
    t._function = fun
    t._type = datatypes.types.FUN
    function t:getType() return self._type end
    function t:waitPids() posix.wait(self:getPid()) end
    function t:getFunction() return self._function end
    function t:setPid(v) self._pid = v end
    function t:getPid() return self._pid end
    function t:execute(fd)
        local out, err, pid = pipeopenFun(fd, self:getFunction(), true)
        self:setPid(pid)
        return out, err, pid
    end
    setmetatable(t, mtab)
    return t
end

function datatypes.Command(program, ...)
    local mtab = {}
    mtab.__call = function(callee, fd)
        return callee:execute(fd)
    end
    local t = {}
    t._pid = nil
    t._program = program
    t._arguments = table.pack(...)
    t._type = datatypes.types.COMMAND
    function t:getPid() return self._pid end
    function t:setPid(v) self._pid = v end
    function t:getType() return self._type end
    function t:waitPids() posix.wait(self:getPid()) end
    function t:getArguments() return self._arguments end
    function t:getProgram() return self._program end
    function t:execute(argfd)
        local out, err, pid = pipeopen(
            argfd, self:getProgram(), table.unpack(self:getArguments()))
        self:setPid(pid)
        return out, err, pid
    end
    setmetatable(t, mtab)
    return t
end

function datatypes.Pipe(left, right)
    local mtab = {}
    local t = {}
    t._left = left
    t._right = right
    t._type = datatypes.types.PIPE
    function t:getLeft() return self._left end
    function t:getRight() return self._right end
    function t:getType() return self._type end
    function t:waitPids()
        -- recursively wait for all pids
        self:getLeft():waitPids()
        self:getRight():waitPids()
    end
    mtab.__call = function(callee, infd)
        local leftSout, leftEout, leftPid = callee:getLeft()(infd)
        local rightSout, rightEout, rightPid = callee:getRight()(leftSout)
        return rightSout, rightEout, rightPid
    end
    setmetatable(t, mtab)
    return t
end

return datatypes
