local util = require("common.util")
local posix = require("posix")
local Pipe = util.Pipe
local mod = {}

function mod.serialize(t)
	-- Your code here
	local stack = {}
	function do_serialize(t)
		if type(t) == "string" then
			table.insert(stack, string.format("%q", t))
		elseif type(t) == "table" then
			table.insert(stack, "{")
			for k, v in pairs(t) do
				do_serialize(k)
				table.insert(stack, " = ")
				do_serialize(v)
				table.insert(stack, ", ")
			end
			table.insert(stack, "}")
		else
			table.insert(stack, tostring(t))
		end
	end
	do_serialize(t)
	return table.concat(stack, "")
end


-- split by the first occurance
function mod.split2(str, pat) 
	local words = {}
	idx = string.find(str, pat)
	if idx == nil then
		return words
	end
	table.insert(words, string.sub(str, 1, idx - 1))
	table.insert(words, string.sub(str, idx + 1))
	return words
end


function mod.deserialize(s)
	-- Your code here
	local idx = 1
	local token_stream = {}
	function get_next_token()
		local flag = false
		while idx <= s:len() and s:sub(idx, idx) == " " do
			idx = idx + 1
		end
		if idx > s:len() then
			return nil
		end
		local c = s:sub(idx, idx)
		if c == "{" or c == "}" or c == "," or c == "=" then
			idx = idx + 1
			return c
		else
			local begin = idx
			local flag = false
			while idx <= s:len() and (s:sub(idx, idx) ~= " " or flag) do
				if s:sub(idx, idx) == "\"" then
					flag = not flag
				end
				idx = idx + 1
			end
			local subs = s:sub(begin, idx - 1)
			local n = subs:len()
			if subs:sub(n, n) == "," then
				idx = idx - 1
			end
			subs = s:sub(begin, idx - 1)
			if subs == "true" then return true
			elseif subs == "false" then return false
			elseif subs == "nil" then return nil
			elseif subs:match("[^%d.]") == nil then return tonumber(subs)
			else
				return subs:sub(2, subs:len() - 1)
			end
		end
	end

	while idx <= s:len() do
		table.insert(token_stream, get_next_token())
	end
	-- for _, v in pairs(token_stream) do
	-- 	print(_, v)
	-- end

	local i = 1
	local len = tablelength(token_stream)
	function do_deserialize()
		while i <= len do
			local token = token_stream[i]
			if token ~= "{" and token ~= "}" then
				i = i + 1
				return token
			elseif token == "{" then
				local t = {}
				i = i + 1
				if token_stream[i] == "}" then
					i = i + 1
					return t
				end
				repeat
					local key = do_deserialize()
					--print(key)
					assert(token_stream[i] == "=")
					i = i + 1
					local value = do_deserialize()
					--print(value)
					assert(token_stream[i] == ",")
					i = i + 1
					t[key] = value
				until token_stream[i] == "}"
				i = i + 1
				return t
			end
		end
	end

	return do_deserialize()
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

function mod.rpcify(class)
	local MyClassRPC = {}
	-- Your code here
	MyClassRPC.new = function ()
		local in_pipe = Pipe.new()	-- father wtries, child reads
		local out_pipe = Pipe.new()	-- child writes, father reads
		local pid = posix.fork()
		if pid == 0 then
			-- child
			local t = class.new()
			while true do
				local msg = mod.deserialize(Pipe.read(in_pipe))
				local cmd = msg[1]
				if cmd == "exit" then
					os.exit()
				end
				local params = table.unpack(msg, 2)
				local result = class[cmd](t, params)
				Pipe.write(out_pipe, mod.serialize(result))
			end
		else
			-- father
			return { pid = pid, in_pipe = in_pipe, out_pipe = out_pipe}
		end
	end

	for key, value in pairs(class) do
		if type(value) == "function" and key ~= "new" then
			MyClassRPC[key] = function (inst, ...)
				local arg = table.pack(...)
				Pipe.write(inst.in_pipe, mod.serialize({key, table.unpack(arg)}))
				return mod.deserialize(Pipe.read(inst.out_pipe))
			end
			MyClassRPC[key.."_async"] = function(inst, ...)
				local arg = table.pack(...)
				return function()
					return MyClassRPC[key](inst, table.unpack(arg))
				end
			end
		end
	end

	MyClassRPC.exit = function (inst)
		Pipe.write(inst.in_pipe, mod.serialize({"exit"}))
		posix.wait(inst.pid)
	end

	return MyClassRPC
end


return mod
