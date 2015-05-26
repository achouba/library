local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Value         = require "cosy.value"

local locale = Configuration.cli.default_locale._

local Commands = {}

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end

Commands ["daemon:stop"] = {
  _   = "cli:daemon:stop",
  run = function (cli, ws)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    return ws:send (Value.expression "daemon-stop")
  end,
}

Commands ["server:start"] = {
  _   = "cli:server:start",
  run = function (cli)
    cli:add_option (
      "-c, --clean",
      "clean redis database"
    )
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    if args.clean then
      local Redis     = require "redis"
      local host      = Configuration.redis.interface._
      local port      = Configuration.redis.port._
      local database  = Configuration.redis.database._
      local client    = Redis.connect (host, port)
      client:select (database)
      client:flushdb ()
      package.loaded ["redis"] = nil
    end
    if io.open (Configuration.server.pid_file._, "r") then
      return {
        success = false,
        error   = I18n {
          _      = "cli:server:already-running",
          locale = locale,
        },
      }
    end
    return os.execute ([==[
      if [ -f "%{pid}" ]
      then
        kill -9 $(cat %{pid})
      fi
      rm -f %{pid} %{log}
      luajit -e 'require "cosy.server" .start ()' > %{log} 2>&1 & sleep 2
    ]==] % {
      pid = Configuration.server.pid_file._,
      log = Configuration.server.log_file._,
    })
  end,
}
Commands ["server:stop"] = {
  _   = "cli:server:stop",
  run = function (cli, ws)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    local serverdata = read (Configuration.server.data_file._)
    ws:send (Value.expression {
      server     = "http://%{interface}:%{port}" % {
        interface = serverdata.interface,
        port      = serverdata.port,
      },
      operation  = "stop",
      parameters = {
        token = serverdata.token,
      },
    })
    return Value.expression (result)
  end,
}

local function addoptions (cli)
  cli:add_option (
    "-s, --server=SERVER",
    I18n {
      _      = "cli:option:server",
      locale = locale,
    },
    Configuration.cli.default_server._
  )
  cli:add_option (
    "-l, --locale=LOCALE",
    I18n {
      _      = "cli:option:locale",
      locale = locale,
    },
    Configuration.cli.default_locale._
  )
end

Commands ["show:information"] = {
  _   = "cli:information",
  run = function (cli, ws)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = args.server,
      operation  = "information",
      parameters = {
        locale = args.locale,
      },
    })
    local result = ws:receive ()
    return Value.decode (result)
  end,
}

Commands ["show:tos"] = {
  _   = "cli:tos",
  run = function (cli, ws)
    addoptions (cli)
    local args = cli:parse_args ()
    if not args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = args.server,
      operation  = "tos",
      parameters = {
        locale = args.locale,
      },
    })
    local result = ws:receive ()
    return Value.decode (result)
  end,
}

-- http://lua.2524044.n2.nabble.com/Reading-passwords-in-a-console-application-td6641037.html
local function getpassword ()
  local stty_ret = os.execute ("stty -echo 2>/dev/null")
  if stty_ret ~= 0 then
    io.write("\027[08m") -- ANSI 'hidden' text attribute 
  end 
  local ok, pass = pcall (io.read, "*l")
  if stty_ret == 0 then
    os.execute("stty sane")
  else 
    io.write("\027[00m")
  end 
  io.write("\n")
  os.execute("stty sane") 
  if ok then 
    return pass
  end 
end

Commands ["user:create"] = {
  _   = "cli:user:create",
  run = function (cli, ws)
    addoptions (cli)
    cli:add_argument (
      "username",
      I18n {
        _      = "cli:argument:username",
        locale = locale,
      }
    )
    cli:add_argument (
      "email",
      I18n {
        _      = "cli:argument:email",
        locale = locale,
      }
    )
    local args = cli:parse_args ()
    if not args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = args.server,
      operation  = "tos",
      parameters = {
        locale = args.locale,
      },
    })
    local tosresult = ws:receive ()
    tosresult = Value.decode (tosresult)
    if not tosresult.success then
      return tosresult
    end
    local digest = tosresult.response.tos_digest
    local passwords = {}
    repeat
      for i = 1, 2 do
        io.write (I18n {
          _      = "cli:argument:password",
          locale = locale,
          count  = i,
        } .. " ")
        passwords [i] = getpassword ()
      end
      if passwords [1] ~= passwords [2] then
        print (I18n {
          _      = "cli:argument:password:nomatch",
          locale = locale,
        })
      end
    until passwords [1] == passwords [2]
    ws:send (Value.expression {
      server     = args.server,
      operation  = "create_user",
      parameters = {
        username   = args.username,
        password   = passwords [1],
        email      = args.email,
        tos_digest = digest,
        locale     = args.locale,
      },
    })
    local result = ws:receive ()
    return Value.decode (result)
  end,
}


return Commands