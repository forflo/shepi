local posix = require("posix")
local ds = require("lua-datatypes")
local dbg = require("debugger")
local pipeDsl = {}

--local pipe =
--    bp.ls("-la", "--foo") |
--    bp.fork(bp.cmd("bar", "--long") | bp.cmd("tr", "'g'", "'f'"),
--            bp.cmd("fnord") | bp.cmd("cat")) |
--    bp.cmd("cat");
--local result = pipe("foo")
local function tableReverse(tab)
    local result = {}
    for i=#tab,1,-1 do
        result[#result + 1] = tab[i]
    end
    return result
end

local function imap(tbl, func)
    local result = {}
    for k, v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

local dslWrap
local dslUnwrap

local mtab = {}
mtab.__bor = function(left, right)
    if type(left) == "function" then left = dslWrap(left) end
    if type(right) == "function" then right = dslWrap(right) end
    return dslWrap(ds.Pipe(dslUnwrap(left), dslUnwrap(right)))
end
mtab.__call = function(callee, str)
--    dbg()
    str = str or ""
    local r1, w1 = posix.pipe()
    local tempFile = posix.fdopen(w1, "w")
    local result, retStr
    local outFd = dslUnwrap(callee)(w1)
    tempFile:write(str)
    tempFile:close()
    result = posix.fdopen(outFd, "r")
    retStr = result:read("a")
    result:close()
    return retStr
end

function dslUnwrap(wrapped)
    return wrapped.pipeOrCmd
end

function dslWrap(pipeOrCmd)
    local result = { pipeOrCmd = pipeOrCmd }
    setmetatable(result, mtab)
    return result
end

function pipeDsl.cmap(fun)
    return function(infd)
        local result = ""
        local tempFile = posix.fdopen(infd, "r")
        local char = tempFile:read(1)
        while char do
            result = result .. fun(char)
            char = tempFile:read(1)
        end
        return result
    end
end

function pipeDsl.lmap(fun)
    return function(infd)
        local result = ""
        local tempFile = posix.fdopen(infd, "r")
        local char = tempFile:read("L")
        while char do
            result = result .. fun(char)
            char = tempFile:read("L")
        end
        return result
    end
end

function pipeDsl.fold(fun, accu)
-- TODO:
end

function pipeDsl.cmd(program, ...)
    return dslWrap(ds.Command(program, ...))
end

function pipeDsl.fork(...)
    local arguments = table.pack(...)
    arguments = imap(arguments, dslUnwrap)
    return dslWrap(function(infd)
            local syncReturns =
                imap(arguments,
                     function(pipeOrCmd)
                         assert(pipeOrCmd:getType() == ds.types.Command
                                    or pipeOrCmd:getType() == ds.types.Pipe,
                                "Wrong types!")
                         local tempfile = posix.fdopen(pipeOrCmd(infd), "r")
                         local result = tempfile:read("a")
                         return result
                end)

            local concated = table.concat(syncReturns)
            local r1, w1 = posix.pipe()
            local tempfile = posix.fdopen(w1, "w")
            tempfile:write(concated)
            tempfile:close()
            return r1
    end)
end

function pipeDsl.forkRev(...)
    return pipeDsl.fork(table.unpack(table.reverse(table.pack(...))))
end

local pdslMtab = {}
pdslMtab.__index = function(tbl, key)
    return function(...)
        return pipeDsl.cmd(key, ...)
    end
end

setmetatable(pipeDsl, pdslMtab)

bp = pipeDsl

print((bp.ls("-la") | bp.cat("-n"))())

return pipeDsl
