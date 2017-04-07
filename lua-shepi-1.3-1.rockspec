package = "lua-shepi"
version = "1.3-1"

source = {
   url = "git://github.com/forflo/shepi"
}

description = {
    summary = "Tiny EDSL for shell pipes in lua",
    detailed = "",
    homepage = "http://www.github.com/forflo/",
    license = "GPLv2"
}

dependencies = {
    "lua >= 5.1, < 5.4",
    "luaposix"
}

build = {
    type = "builtin",
    modules = {
        ["lua-shepi"] = "source/lua-shepi.lua",
        ["lua-shepi-datatypes"] = "source/lua-shepi-datatypes.lua"
    }
}
