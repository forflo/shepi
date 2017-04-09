# Lua-Shepi
## Why and What

Lua-shepi provides an embedded domain specific language
for the creation of shell pipes.

Lua, by itself, only provides the function `popen` which
takes as much arguments as you want, and then executes
the command named by the first argument and uses the remaining
arguments as the command's parameters. Finally, `popen` returns
a lua file object from which one can read the output of the
process. This neat function and lua's expresiveness (metatables y0!)
make something like `cmd.cat(cmd.ls('-lah'))` possible.

Serge Zaitsev wrote an [article](http://zserge.com/blog/luash.html)
on his blog describing
a tiny lua library that implements the `cmd1(cmd2('param'))` abstraction.

I like this idea. However, there are some caveats:

1. Due to the limitation on `popen`, the library uses tempfiles for each
   process started.
2. For the same reason, and because of lua's synchronicity, only one command
   is being executed at a time (resulting in one tempfile each).
3. If you have something like `ls | cat -n | sed -e 's/foo/bar/'` and
   translate it to his lua-sh syntax, you will end up with
   `ls(cat(sed('-e', 's/foo/bar/'), '-n'))`; which is hardly more readable
   (despite the fact that the author claims that in his article).
   Not only is it not more readable, it is also more difficult to modify,
   especially when you have to add a parameter to a command in the pipeline
   where there was none before. Imagine you would want to add the parameter
   `--bar` to `cat` and `-lah` to `ls`. It is as straight forward to go
   from `ls | cat -n | sed -e 's/foo/bar/'` to
   `ls -lah | cat -n --bar | sed -e 's/foo/bar/'`
   as it is obvious which command the additional parameters belong to.
   For Zaitsev's solution, both things do not hold true.
   Just consider the transition from `ls(cat(sed('-e', 's/foo/bar/'), '-n'))` to
   `ls(cat(sed('-e', 's/foo/bar/'), '-n' '--bar') '-lah')`. And now
   imagine yourself doing that for a pipeline with two commands more...


## Solution

Lua-shepi uses the package lua-posix and thus is capable of dealing
with *real* pipes. Here are some highlights:

- The EDSL uses the same left-to-right evaluation order and
  the pipe character `|` that you are familiar with. For instance
  `local pipe = bp.echo('foo bar') | bp.tr('-d', ' ')` becomes
  possible (see the examples further below).
- There are no tempfiles.
- Space complexity for normal shepi pipes is
  constant (not taking into account the
  commands in the pipeline of course).
- If you are using the `shepi.fork` function,
  space complexity is `O(n) = n`, because
  it synchronuously joins the subpipes in order.
  (`n` referes to the data input from the subpipes.)
- You can throw lua functions into the pipe.
  They also do run in a separate process!
- You can reuse your pipes, since they are just
  regular lua-functions.
- And, of course, there won't be zombie processes
  (but that's not really a hightlight).

## Showcase

Now, without further ado, let me show you some actual use cases

### Simple Commands
```lua
local bp = require("lua-shepi")

local ls = bp.ls('-la')
local echo = bp.echo()
local bash = bp.bash()
print(ls())                  -- prints files from pwd
print(bash("ls -la"))        -- does the same
print(bash(echo("ls -la")))  -- does the same
```

### Simple Pipelines

```lua
local bp = require("lua-shepi")

local simplePipe0 = bp.ls('-a') | bp.cat('-n')

local simplePipe1 =
    simplePipe0 |
    bp.sed('-e', 's/4/four/g') |
    bp.cat('-n')

local simplePipe2 = simplePipe1 | bp.cat('-n')

local get4th = bp.head('-n4') | bp.tail('-n1')

local p1 = simplePipe0 | get4th
local p2 = simplePipe1 | get4th
local p3 = simplePipe2 | get4th

print(p1())
print(p2())
print(p3())
```

If you let the above code run, it would produce something
simlar to the following output.

```
     4	debugger.lua

     4	     four	debugger.lua

     4	     4	     four	debugger.lua
```

Also note that, since lua has special syntax sugar
for functions that only take one string or one table
as input, we could have written the above program
like so:

```lua
-- [...]
local simplePipe0 = bp.ls'-a' | bp.cat'-n'

local simplePipe1 =
    simplePipe0 |
    bp.sed('-e', 's/4/four/g') |
    bp.cat'-n'

local simplePipe2 = simplePipe1 | bp.cat'-n'

local get4th = bp.head'-n4' | bp.tail'-n1'
-- [...]
```

### Lua Function Inside of Pipes

It is also possible to throw lua functions into
a shepi pipeline. The next code shows this.

```lua
local bp = require("lua-shepi")

local function cmap(sin, sout, serr)
    local char = sin:read(1)
    while char do
        sout:write(char .. char)
        char = sin:read(1)
    end
end

local pipe = bp.echo('-n', 'A test Message') | bp.fun(cmap)
print(pipe())
```

This would output `AA  tteesstt  MMeessssaaggee`. Note, that
functions will be run inside a forked lua interpreter and
cannot interface with upvalues from the interpreter it was
forked from!

### Synchronous "Forks" inside of Pipes

Consider the following: You have two different transformations
that you want to apply onto your stream and you want to somehow
join both resulting streams together at the end of the fork.

To illustrate this problem, take a look at the bash line

```bash
echo data | \
    tee >(cat) \
        >(cat -n) >/dev/null | \
    cat
```

Depending on the current wheather, the current time and date
and the filling status of your coffee machine's beans container,
the output of the bash line depicted could be either

```bash
     1	foo
foo
```

or

```bash
foo
     1	foo
```

Which means it is \*starts scary voice\* non-deterministic!

In lua-shepi, I chose a deterministic mode of operation, because
most of the time when I did something like the `tee` hack with
process substitution, I *cared* about the order and had to
resort to lock files or temp files in order to "synchronize" the
output again. You can imagine that this was rather painful and
ugly.

So here is what it looks like in lua using shepi:

```lua
local bp = require("lua-shepi")

local function hline(len, char)
    return function (sin, sout, serr)
        sout:write(string.rep(char, len) .. '\n')
        sout:write(sin:read("a"))
        sout:write(string.rep(char, len) .. '\n')
    end
end

pipe =
    bp.ls('-lh') |
    bp.fun(hline(20, '-')) |
    bp.fork(
        bp.cat('-n'),
        bp.cat('-n') | bp.tac(),
        bp.sed('-e', 's/[0-9]/?/g') |
            bp.fork(
                bp.cat('-n'),
                bp.cat('-n') | bp.tac()))

print(pipe())
```

If run in a directory with only two files, the output would look like:

```
     1	--------------------
     2	total 12K
     3	-rw-r--r-- 1 florian florian 5.0K Apr  6 22:43 lua-datatypes.lua
     4	-rw-r--r-- 1 florian florian 3.4K Apr  6 22:43 lua-pipeDsl.lua
     5	--------------------
     5	--------------------
     4	-rw-r--r-- 1 florian florian 3.4K Apr  6 22:43 lua-pipeDsl.lua
     3	-rw-r--r-- 1 florian florian 5.0K Apr  6 22:43 lua-datatypes.lua
     2	total 12K
     1	--------------------
     1	--------------------
     2	total ??K
     3	-rw-r--r-- ? florian florian ?.?K Apr  ? ??:?? lua-datatypes.lua
     4	-rw-r--r-- ? florian florian ?.?K Apr  ? ??:?? lua-pipeDsl.lua
     5	--------------------
     5	--------------------
     4	-rw-r--r-- ? florian florian ?.?K Apr  ? ??:?? lua-pipeDsl.lua
     3	-rw-r--r-- ? florian florian ?.?K Apr  ? ??:?? lua-datatypes.lua
     2	total ??K
     1	--------------------
```

## Tests

All of the examples in the previous chapter, were coded into
a unit tests and put into the `tests` directory (relative to the
root of the repository). The test uses the lua test framework
[busted](https://github.com/Olivine-Labs/busted) and can be
executed using the following command line:

```bash
busted -lpath "./source/?.lua" --pattern "spec" tests/
```

Note, that this command must be issued from within the repository
root.
