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

local dslWrap
local dslUnwrap

local mtab = {}
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

setmetatable(pipeDsl, pdslMtab)

bp = pipeDsl

--print(bp.cat()("foobar"))
--print((bp.ls("-la") | bp.cat("-n") | bp.sed('-e', 's/9/goo/g') | bp.cat('-n'))())
--
--local function cmap(sin, sout, serr)
--    local char = sin:read(1)
--    while char do
--        sout:write(char .. char)
--        char = sin:read(1)
--    end
--end
--print((bp.echo('-n', 'A test Message') | bp.fun(cmap))())
--print((bp.ls() | bp.forkRev(bp.cat('-n')) | bp.cat())())


local function hline(len, char)
    return function (sin, sout, serr)
        sout:write(string.rep(char, len) .. '\n')
        sout:write(sin:read("a"))
        sout:write(string.rep(char, len) .. '\n')
    end
end

pipe =
    bp.ls('-lah') |
    bp.fun(hline(20, '-')) |
    bp.fork(
        bp.cat('-n'),
        bp.cat('-n') | bp.tac(),
        bp.sed('-e', 's/[0-9]/?/g') |
            bp.fork(
                bp.cat('-n'),
                bp.cat('-n') | bp.tac()))

for i = 1, 20 do
    print(pipe())
    print(pipe())
end

posix.sleep(30)

return pipeDsl
