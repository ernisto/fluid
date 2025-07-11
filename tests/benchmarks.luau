local testkit = require("@vendor/testkit")
local BENCH, START = testkit.benchmark()

local fluid = require("../src")
local source = fluid.source
local derive = fluid.derive
local indexes = fluid.for_keys
local values = fluid.for_values
local cleanup = fluid.cleanup

local function TITLE(name: string)
	print()
	print(testkit.color.white(name))
end

local function ROOT_BENCH(name: string, fn: () -> ())
	fluid.root(function(destroy)
		BENCH(name, fn)
		return destroy
	end)()
end

local N = 2 ^ 18 -- 262144

TITLE("sources")

BENCH("create source", function()
	local cache = table.create(N)

	for i = 1, START(N) do
		cache[i] = source(1)
	end
end)

BENCH("get value", function()
	local src = source(1)

	for i = 1, START(N) do
		src()
	end
end)

BENCH("set value", function()
	local src = source(1)

	for i = 1, START(N) do
		src(i)
	end
end)

ROOT_BENCH("derive 1 source", function()
	local cache = table.create(N)
	local src = source(1)

	for i = 1, START(N) do
		cache[i] = derive(function()
			return src()
		end)
	end
end)

ROOT_BENCH("derive 4 sources", function()
	local cache = table.create(N)
	local src = fluid.source(1)
	local src2 = fluid.source(2)
	local src3 = fluid.source(3)
	local src4 = fluid.source(4)

	for i = 1, START(N) do
		cache[i] = derive(function()
			return src() + src2() + src3() + src4()
		end)
	end
end)

TITLE("graphs")

ROOT_BENCH("update 1->1 graph", function()
	local src = source(1)

	local _derived = derive(function()
		return src()
	end)

	for i = 1, START(N) do
		src(i)
	end
end)

ROOT_BENCH("update 1->1 graph with cleanup", function()
	local src = source(1)

	derive(function()
		cleanup(function() end)
		return src()
	end)

	for i = 1, START(N) do
		src(i)
	end
end)

ROOT_BENCH("update 1->1000 graph", function()
	local src = source(-1)

	for i = 1, 1000 do
		derive(function()
			return src()
		end)
	end

	src(0)

	for i = 1, START(10) do
		src(i)
	end
end)

ROOT_BENCH("update 1->1->1->1...1000 graph", function()
	local src = source(-1)

	local last = src
	for i = 1, 1000 do
		local l = last
		last = derive(function()
			return l()
		end)
	end

	src(0)

	for i = 1, START(10) do
		src(i)
	end
end)

ROOT_BENCH("update 1000->1 graph", function()
	local srcs = {}
	for i = 1, 1000 do
		srcs[i] = source(0)
	end

	derive(function()
		for i = 1, 1000 do
			srcs[i]()
		end
		return false
	end)

	for idx = 1, START(1000) do
		srcs[idx](idx)
	end
end)

ROOT_BENCH("update all parents of 1000->1 graph", function()
	local srcs = {}
	for i = 1, 1000 do
		srcs[i] = source(0)
	end

	derive(function()
		for i = 1, 1000 do
			srcs[i]()
		end
		return false
	end)

	for i = 1, START(1) do
		for idx = 1, 1000 do
			srcs[idx](i)
		end
	end
end)

ROOT_BENCH("update all parents of 1000->1 graph (batched)", function()
	if true then
		return warn("unavailable batching")
	end
	local srcs = {}
	for i = 1, 1000 do
		srcs[i] = source(0)
	end

	derive(function()
		for i = 1, 1000 do
			srcs[i]()
		end
		return false
	end)

	for i = 1, START(1) do
		-- batch(function()
		--     for idx = 1, 1000 do
		--         srcs[idx](i)
		--     end
		-- end)
	end
end)

-- todo: optimize this case
ROOT_BENCH("update 1000 1->1 common extern. graph", function()
	local ext = source(-1)

	local srcs = {}
	for i = 1, 1000 do
		srcs[i] = source(0)
		derive(function()
			return srcs[i]() + ext()
		end)
	end

	ext(0)

	for i = 1, START(10) do
		for idx = 1, 1000 do
			srcs[idx](i)
		end
	end
end)

-- TITLE("property apply")

-- ROOT_BENCH("apply 0 properties", function()
-- 	local apply = require("../src/instances/bind")
-- 	local instance = create("Frame")({})

-- 	for i = 1, START(N) do
-- 		apply(instance, {})
-- 	end
-- end)

-- ROOT_BENCH("apply 8 properties", function()
-- 	local apply = require("../src/instances/bind")
-- 	local instance = create("Frame")({})

-- 	for i = 1, START(N) do
-- 		apply(instance, {
-- 			Text = i,
-- 			Text2 = i,
-- 			Text3 = i,
-- 			Text4 = i,
-- 			Text5 = i,
-- 			Text6 = i,
-- 			Text7 = i,
-- 			Text8 = i,
-- 		})
-- 	end
-- end)

-- ROOT_BENCH("bind property", function()
-- 	local apply = require("../src/instances/bind")

-- 	local instance = create("Frame")({})
-- 	local src = source(1)

-- 	for i = 1, START(N) do
-- 		apply(instance, {
-- 			Text = src,
-- 		})
-- 	end

-- 	return nil
-- end)

-- ROOT_BENCH("update binding", function()
-- 	local apply = require("../src/instances/bind")

-- 	local instance = create("Frame")({})
-- 	local src = source(1)

-- 	apply(instance, {
-- 		Text = src,
-- 	})

-- 	for i = 1, START(N) do
-- 		src(i)
-- 	end

-- 	return nil
-- end)

TITLE("indexes()")

N /= 1024

ROOT_BENCH("indexes() all new", function()
	local data = {}

	for i = 1, N do
		data[i] = i
	end

	local src = source(data)

	START(N)

	local _list = indexes(src, function(v, i)
		return {}
	end)

	return nil
end)

ROOT_BENCH("indexes() no change", function()
	local data = {}

	for i = 1, N do
		data[i] = i
	end

	local src = source(data)

	local _list = indexes(src, function(v, i)
		return {}
	end)

	START(N)

	src(data)

	return nil
end)

ROOT_BENCH("indexes() all change", function()
	local data = {}

	for i = 1, N do
		data[i] = i
	end

	local src = source(data)

	local _list = indexes(src, function(v, i)
		return {}
	end)

	--src(src()) -- fill double buffer

	for i, v in data do
		data[i] = v + 1
	end

	START(N)

	src(data)
end)

ROOT_BENCH("indexes() all remove", function()
	local data = {}

	for i = 1, N do
		data[i] = i
	end

	local src = source(data)

	local _list = indexes(src, function(v, i)
		return {}
	end)

	table.clear(data)

	START(N)

	src(data)

	return nil
end)

TITLE("values()")

ROOT_BENCH("values() all new", function()
	local data = {}

	for i = 1, N do
		data[i] = {}
	end

	local src = source(data)

	START(N)

	local _list = values(src, function(v, i)
		return {}
	end)

	return nil
end)

ROOT_BENCH("values() no change", function()
	local data = {}

	for i = 1, N do
		data[i] = {}
	end

	local src = source(data)

	local _list = values(src, function(v, i)
		return {}
	end)

	src(src()) -- fill double buffer

	START(N)

	src(data)
end)

ROOT_BENCH("values() all change", function()
	local data = {}

	for i = 1, N do
		data[i] = {}
	end

	local src = source(data)

	local _list = values(src, function(v, i)
		return {}
	end)

	src(src()) -- fill double buffer

	for i = 1, N do
		local r = math.random(1, #data)
		data[i], data[r] = data[r], data[i]
	end

	START(N)

	src(data)
end)

ROOT_BENCH("values() all remove", function()
	local data = {}

	for i = 1, N do
		data[i] = {}
	end

	local src = source(data)

	local _list = values(src, function(v, i)
		return {}
	end)

	table.clear(data)

	START(N)

	src(data)
end)

TITLE("spring()")

ROOT_BENCH("spring update", function()
	local source, spring = fluid.source, fluid.spring

	local src = source(vector.create(0, 0, 0))

	for i = 1, N do
		spring(src, 1, 1)
	end

	START(N)

	src(vector.create(1, 1, 1))
end)

ROOT_BENCH("spring step", function()
	local spring_step = require("../src/anim/spring/spring_file").step
	local source, spring = fluid.source, fluid.spring

	local src = source(vector.create(0, 0, 0))

	for i = 1, N do
		spring(src, 1, 1)
	end

	src(vector.create(1, 1, 1))

	START(N)

	spring_step(1 / 60)
end)

return nil
