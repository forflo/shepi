local posix = require("posix")
local ds = require("lua-shepi-datatypes")

local pipeDsl = {}
local dslWrap
local dslUnwrap

local mtab = {}

local function tableReverse(tab)
    local result = {}
    for i = #tab, 1, -1 do
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

mtab.__bor = function(left, right)
    if type(left) == "function" then left = dslWrap(left) end
    if type(right) == "function" then right = dslWrap(right) end
    return dslWrap(ds.Pipe(dslUnwrap(left), dslUnwrap(right)))
end
mtab.__call = function(callee, str)
    str = str or ""
    local r1, w1 = posix.pipe()
    local w1File = posix.fdopen(w1, "w")
    w1File:write(str)
    w1File:close()
    local out = dslUnwrap(callee)(r1)
    local outFile, retStr
    outFile = posix.fdopen(out, "r")
    retStr = outFile:read("a")
    outFile:close()
    dslUnwrap(callee):waitPids()
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

function pipeDsl.fun(f)
    return dslWrap(ds.Fun(f))
end

function pipeDsl.cmd(program, ...)
    return dslWrap(ds.Command(program, ...))
end

function pipeDsl.fork(...)
    return dslWrap(
        ds.SyncFork(
            table.unpack(
                imap(table.pack(...), dslUnwrap))))
end

function pipeDsl.forkRev(...)
    return pipeDsl.fork(
        table.unpack(
            tableReverse(
                table.pack(...))))
end

local pdslMtab = {}
pdslMtab.__index = function(tbl, key)
    return function(...)
        return pipeDsl.cmd(key, ...)
    end
end

pdslMtab.__call = function(callee, program, ...)
    return pipeDsl.cmd(program, ...)
end

setmetatable(pipeDsl, pdslMtab)
return pipeDsl
