describe(
    "A simple moketest",
    function()
        randomize(true)

        setup("Just library loading and this kind of necessary stuff",
              function()
                  bp = require("lua-shepi")
        end)

        it("tests simple commands",
           function()
               local ls = bp.ls('-la')
               local echo = bp.echo()
               local bash = bp.bash()
               assert.are.same((ls()), (bash("ls -la")), (bash(echo("ls -la"))))
        end)

        it("tests simple pipelines",
           function()
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
               assert.Truthy(p1())
               assert.Truthy(p2())
               assert.Truthy(p3())
        end)

        it("tests functions inside of pipes",
           function()
               local function cmap(sin, sout, serr)
                   local char = sin:read(1)
                   while char do
                       sout:write(char .. char)
                       char = sin:read(1)
                   end
               end
               local pipe = bp.echo('-n', 'A test Message') | bp.fun(cmap)
               assert.are.same(pipe(), "AA  tteesstt  MMeessssaaggee")
        end)

        it("tests forks inside of pipes",
           function()
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
               local result = pipe()
               assert.Truthy(result)
               assert.True(#result > 0)
        end)
end)
