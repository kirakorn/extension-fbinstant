if fbinstant then return end
fbinstant = {
	mock = true
}

local function get_save_path(name)
	local application_id = sys.get_config("project.title"):gsub(" ", "_")
	return sys.get_save_file(application_id, "fbinstant_" .. name)
end

local function save(name, data)
	assert(name, "You must provide a filename")
	assert(data and type(data) == "table", "You must provide a table to save")
	return sys.save(get_save_path(name), data)
end

local function load(name)
	assert(name, "You must provide a filename")
	return sys.load(get_save_path(name))
end


local rxijson = require "fbinstant.utils.json"

fbinstant.CONTEXT_SOLO = "SOLO"
fbinstant.CONTEXT_POST = "POST"
fbinstant.CONTEXT_THREAD = "THREAD"
fbinstant.CONTEXT_GROUP = "GROUP"

fbinstant.SHARE_INTENT_INVITE = "INVITE"
fbinstant.SHARE_INTENT_REQUEST = "REQUEST"
fbinstant.SHARE_INTENT_CHALLENGE = "CHALLENGE"
fbinstant.SHARE_INTENT_SHARE = "SHARE"

fbinstant.FILTER_NEW_CONTEXT_ONLY = "NEW_CONTEXT_ONLY"
fbinstant.FILTER_INCLUDE_EXISTING_CHALLENGES = "INCLUDE_EXISTING_CHALLENGES"
fbinstant.FILTER_NEW_PLAYERS_ONL = "NEW_PLAYERS_ONLY"

fbinstant.STORE_ACTIVE = "ACTIVE"
fbinstant.STORE_ENDED = "ENDED"


local player_data = {}

local entry_point_data = {}

local session_data = {}

local player_stats = {}


fbinstant.PLAYER = {}
fbinstant.PLAYERS = {}
fbinstant.CONTEXT = nil

local function get_self()
	return _G["__dm_script_instance__"]
end
--------------------------------
--------------- LIFECYCLE
--------------------------------

function fbinstant.initialize(cb)
	print("initialize")
	cb(get_self(), true)
end

function fbinstant.set_loading_progress()
	print("set_loading_progress")
end

function fbinstant.start_game(cb)
	print("start_game")
	cb(get_self(), true)
end

function fbinstant.update(jsondata, cb)
	print("update", jsondata)
	cb(get_self(), true)
end

function fbinstant.quit()
	print("quit")
end


--------------------------------
--------------- MISC FUNCTIONS
--------------------------------

function fbinstant.log_event(event_name, value_to_sum, params)
	print("log_event", event_name, value_to_sum, params)
end

function fbinstant.share(payload, cb)
	print("share")
	pprint(rxijson.decode(payload))
	cb(get_self(), true)
end


--------------------------------
--------------- SESSION AND ENTRY DATA
--------------------------------

function fbinstant.get_entry_point_data(key)
	print("get_entry_point_data", key)
	return entry_point_data[key]
end

function fbinstant.get_entry_point(cb)
	print("get_entry_point")
	return cb(get_self(), "entrypoint")
end

function fbinstant.set_session_data(jsondata)
	print("set_session_data", jsondata)
	session_data = json.decode(jsondata)
end


--------------------------------
--------------- PLAYER FUNCTIONS
--------------------------------

function fbinstant.get_player()
	print("get_player")
	return fbinstant.PLAYER
end

function fbinstant.get_player_data(key, cb)
	print("get_player_data", key)
	cb(get_self(), player_data[key])
end

function fbinstant.set_player_data(jsondata, cb)
	print("set_player_data", jsondata)
	player_data = json.decode(jsondata)
	cb(get_self(), true)
end

function fbinstant.flush_player_data(cb)
	print("flush player data")
	cb(get_self(), true)
end

function fbinstant.get_player_stats(stat, cb)
	print("get player stats", stats)
	cb(get_self(), player_stats[stat] or 0)
end

function fbinstant.set_player_stats(statsjson, cb)
	print("set player stats", statsjson)
	player_stats = json.decode(statsjson)
	cb(get_self(), true)
end

function fbinstant.increment_player_stats(statsjson, cb)
	local stats = json.decode(statsjson)
	print("increment player stats")
	for k,v in pairs(stats) do
		player_stats[k] = player_stats[k] or 0
		player_stats[k] = player_stats[k] + v
	end
	cb(get_self(), rxijson.encode(player_stats))
end




--------------------------------
--------------- CONTEXT FUNCTIONS
--------------------------------

function fbinstant.choose_context(cb)
	print("choose_context")
	cb(get_self(), fbinstant.CONTEXT and fbinstant.CONTEXT.id, fbinstant.CONTEXT and fbinstant.CONTEXT.type)
end

function fbinstant.create_context(player_id, cb)
	print("create_context")
	cb(get_self(), fbinstant.CONTEXT and fbinstant.CONTEXT.id, fbinstant.CONTEXT and fbinstant.CONTEXT.type)
end

function fbinstant.switch_context(context_id, cb)
	print("switch_context")
	fbinstant.CONTEXT.id = context_id
	cb(get_self(), fbinstant.CONTEXT and fbinstant.CONTEXT.id, fbinstant.CONTEXT and fbinstant.CONTEXT.type)
end

function fbinstant.get_context()
	return fbinstant.CONTEXT and fbinstant.CONTEXT.id or nil, fbinstant.CONTEXT and fbinstant.CONTEXT.type or nil
end

function fbinstant.is_size_between(min, max)
	if not fbinstant.CONTEXT then
		return false
	end
	return fbinstant.CONTEXT.size >= min and fbinstant.CONTEXT.size <= max
end

function fbinstant.get_players(cb)
	print("get_players")
	cb(get_self(), fbinstant.PLAYERS)
end


--------------------------------
--------------- ACTIVITY STORE
--------------------------------

local function store_filename(store_name, context_id)
	context_id = context_id or fbinstant.CONTEXT.id
	return "store" .. context_id .. store_name
end

local function load_store(store_name, context_id)
	local filename = store_filename(store_name, context_id)
	local store = load(filename)
	if not store or not next(store) then
		store = nil
	end
	return store
end

local function save_store(store)
	local filename = store_filename(store.info.name, store.info.contextID)

	local stores = load("stores")
	stores[store.info.contextID] = stores[store.info.contextID] or {}
	table.insert(stores[store.info.contextID], store.name)
	save("stores", stores)

	save(filename, store)
end

function fbinstant.create_store(store_name, cb)
	print("create_store", store_name)
	local store = load_store(store_name)
	if store then
		cb(get_self(), nil)
	else
		local store = {
			info = {
				contextID = fbinstant.CONTEXT.id,
				id = socket.gettime(),
				name = store_name,
				status = fbinstant.STORE_ACTIVE,
			},
			data = {},
		}
		save_store(store)
		cb(get_self(), store.info.id)
	end
end

function fbinstant.close_store(store_name, cb)
	print("close_store", store_name)
	local store = load_store(store_name)
	if not store then
		cb(get_self(), false)
	else
		store.info.status = fbinstant.STORE_ENDED
		save_store(store)
		cb(get_self(), true)
	end
end

function fbinstant.get_stores(cb)
	print("get_stores")
	local context_id = fbinstant.CONTEXT.id

	local stores = load("stores")	
	stores[context_id] = stores[context_id] or {}
	local result = {}
	for _,store_name in pairs(stores[context_id]) do
		local store = load_store(store_name)
		table.insert(result, store.info)
	end
	cb(get_self(), rxijson.encode(result))
end

function fbinstant.get_store_data(store_name, keys_json, cb)
	print("get_store_data", store_name, keys_json)

	local store = load_store(store_name, fbinstant.CONTEXT.id)
	if not store then
		cb(get_self(), nil)
	else
		local keys = json.decode(keys_json)
		local data = {}
		for i,key in ipairs(keys) do
			data[key] = store.data[key]
		end
		cb(get_self(), rxijson.encode(data))
	end
end

function fbinstant.save_store_data(store_name, data_json, cb)
	print("save_store_data", store_name, data_json)
	local store = load_store(store_name, fbinstant.CONTEXT.id)
	if not store then
		cb(get_self(), nil)
	else
		local data = json.decode(data_json)
		for k,v in pairs(data) do
			store.data[k] = v
		end
		save_store(store)
		cb(get_self(), true)
	end
end

function fbinstant.increment_store_data(store_name, data_json, cb)
	print("increment_store_data", store_name, data_json)
	local store = load_store(store_name, fbinstant.CONTEXT.id)
	if not store then
		cb(get_self(), nil)
	else
		local data = json.decode(data_json)
		local result = {}
		for k,v in pairs(data) do
			store.data[k] = store.data[k] or 0
			store.data[k] = store.data[k] + v
			result[k] = store.data[k]
		end
		save_store(store)
		cb(get_self(), rxijson.encode(result))
	end
end



