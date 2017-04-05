local posix = require("posix")

local util = {}

local ntostring
function ntostring(tbl, indent)
    local function rep(i) return string.rep(" ", i) end
    local indent = indent or 0
    if type(tbl) == "table" then
        local s = "{" .. "\n"
        for k, v in pairs(tbl) do
            s = s .. rep(indent + 2) .. tostring(k)
                .. " = " .. ntostring(v, indent + 2) .. "\n"
        end
        s = s .. rep(indent) .. "}"
        return s
    else
        return tostring(tbl)
    end
end
util.tostring = ntostring

function util.pipeopen(path, ...)
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

--print(util.tostring{1,2,3})
--print(util.tostring{"foo", "bar"})
--print(util.tostring{1,{"foo", "bar"},2,3,{3,4,{4,5,6}}})
--print(util.tostring({1,{"foo", "bar"},2,3,{3,4,{4,5,6}}}))

function util.max(n1, n2)
    return expIfStrict(n1 <= n2, n2, n1)
end

function util.strToOpstr(str)
    if str == "add" then return "+"
    elseif str== "sub" then return "-"
    elseif str== "unm" then return "-"
    elseif str == "mul" then return "*"
    elseif str == "div" then return "/"
    elseif str == "idiv" then return "//"
    elseif str == "bor" then return "|"
    elseif str == "shl" then return "<<"
    elseif str == "len" then return "#"
    elseif str == "pow" then return "^"
    elseif str == "mod" then return "%"
    elseif str == "band" then return "&"
    elseif str == "concat" then return ".." -- probably special case
    elseif str == "lt" then return "<"
    elseif str == "not" then return str
    elseif str == "and" then return str
    elseif str == "or" then return str
    elseif str == "gt" then return ">"
    elseif str == "le" then return "<="
    elseif str == "le" then return "<="
    elseif str == "eq" then return "=="
    else
        print("Serializer: Unknown operator!")
        os.exit(1)
    end
end

util.iterate = function() end
function util.iterate(fun, arg, n)
    if (n <= 1) then return fun(arg)
    else return util.iterate(fun, fun(arg), n - 1) end
end

-- adds indentation and optionally a comment
function util.augmentLine(indent, line, comment)
    if comment then comment = " # " .. comment end
    return string.format("%s%s %s",
                         string.rep(" ", indent),
                         line,
                         comment or "")
end

function util.expIf(cond, funTrue, funFalse)
    if cond then return funTrue()
    else return funFalse() end
end

function util.expIfStrict(cond, expTrue, expFalse)
    if cond then return expTrue
    else return expFalse end
end

function util.filter(tbl, fun)
    local result = {}
    for k, v in pairs(tbl) do
        if fun(v) then result[#result + 1] = v end
    end
    return result
end

function util.ifold(tbl, fun, acc)
    for k, v in ipairs(tbl) do
        acc = fun(v, acc)
    end
    return acc
end

function util.map(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

function util.imap(tbl, func)
    local result = {}
    for k, v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

function util.join(strings, char)
    if #strings == 0 then return "" end
    local result = strings[1]
    if #strings == 1 then return strings[1] end
    for i=2, #strings do
        result = result .. char .. strings[i]
    end
    return result
end

function util.getUniqueId()
    if not util.uniqueCounter then util.uniqueCounter = 0 end
    local result = util.uniqueCounter
    util.uniqueCounter = util.uniqueCounter + 1
    return result
end

function util.zipI(left, right)
    if (left == nil or right == nil) then return nil end
    if #left ~= #right then return nil end
    result = {}
    for k,v in ipairs(left) do
        result[k] = {left[k], right[k]}
    end
    return result
end

function util.addLine(indent, lines, line, comment)
    lines[#lines + 1] = util.augmentLine(indent, line, comment)
end

function util.tableIAddInplace(dest, source)
    local dest = dest or {} -- make new table if dest is nil
    for k, v in ipairs(source) do dest[#dest + 1] = v end
    return dest
end

function util.tableFullAdd(left, right)
    result = {}
    for k, v in pairs(left) do result[#result + 1] = v end
    for k, v in pairs(right) do result[#result + 1] = v end
    return result
end

function util.tableIAdd(left, right)
    result = {}
    for k,v in ipairs(left) do result[#result + 1] = v end
    for k,v in ipairs(right) do result[#result + 1] = v end
    return result
end

function util.tableSlice(tbl, first, last, step)
  local sliced = {}
  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end
  return sliced
end

function util.incCC(config)
    config.columnCount = config.columnCount + config.indentSize
end

function util.decCC(config)
    config.columnCount = config.columnCount - config.indentSize
end

function util.statefulIIterator(tbl)
    local index = 0
    return function()
        index = index + 1
        return tbl[index]
    end
end

function util.tableGetKeyset(tbl)
    local n = 0
    local keyset = {}
    for k, _ in pairs(tbl) do
        n = n + 1
        keyset[n] = k
    end
    return keyset
end

-- can also be used in conjunction with for in loops
-- example:
-- for k, v in statefulKVIterator{x = 1, y = 2, z = 3, 1, 2, 3} do
--     print (k, v)
-- end
function util.statefulKVIterator(tbl)
    local keyset = tableGetKeyset(tbl)
    local keyIdx = 0
    return function()
        keyIdx = keyIdx + 1
        return keyset[keyIdx], tbl[keyset[keyIdx]]
    end
end

function util.tblCountAll(table)
    local counter = 0
    for _1, _2 in pairs(table) do
        counter = counter + 1
    end
    return counter
end

function util.extractIPairs(tab)
    local result = {}
    for k,v in ipairs(tab) do
        result[#result + 1] = v
    end
    return result
end

function util.tableReverse(tab)
    local result = {}
    for i=#tab,1,-1 do
        result[#result + 1] = tab[i]
    end
    return result
end

-- does scope analysis tailored towards closure detection
function util.traverser(ast, func, environment, predicate, recur)
    if type(ast) ~= "table" then return end
    if predicate(ast) then
        func(ast, environment)
        -- don't traverse this subtree.
        -- the function func takes care of that
        if not (recur) then
            return
        end
    end
    for k, v in ipairs(ast) do
        traverser(v, func, environment, predicate, recur)
    end
end

function util.getNodePredicate(typ)
    return function(node)
        if node.tag == typ then return true
        else return false end
    end
end

function util.getUsedSymbols(ast)
    local visitor = function(astNode, env)
        env[astNode[1]] = true
    end
    local result = {}
    traverser(ast, visitor, result, getNodePredicate("Id"), true)
    return tableGetKeyset(result)
end

-- currying just for fun
function util.fillup(column)
    return function(str)
        local l = string.len(str)
        if column > l then
            return string.format("%s%s", str, string.rep(" ", column - l))
        else
            return str
        end
    end
end

-- function composition
-- compose(fun1, fun2)("foobar") = fun1(fun2("foobar"))
function util.compose(funOuter)
    return function(funInner)
        return function(x)
            return funOuter(funInner(x))
        end
    end
end

return util
