
 local HUD_Overlay = false --show glider struts as overlay on HUD
local debug = false --show debug info in top-center of hud
local moveModelUp = false
if tonumber(string.sub(minetest.get_version().string, 1, 1)) and
	tonumber(string.sub(minetest.get_version().string, 1, 1)) > 4 then
	moveModelUp = true
end
hangglider = {} --Make this global, so other mods can tell if hangglider exists.
hangglider.use = {}
if HUD_Overlay then
	hangglider.id = {}  -- hud id for displaying overlay with struts
end
if debug then  hangglider.debug = {} end -- hud id for debug data
--hangglider.airbreak = {}  -- true if falling fast when equip
--[[
minetest.register_entity("hangglider:airstopper", { --A one-instant entity that catches the player and stops them.
	is_visible = false,
	physical = false,
	immortal = true,
	attach = nil,
	on_step = function(self, _)
		local canExist = false
		if self.attach then
			local player = self.attach
			if player:is_player() then
				local pname = player:get_player_name()
				canExist = true
				if player:get_player_velocity().y < 0.5 and player:get_player_velocity().y > -0.5 then
					--Let go when the player actually stops, as that's the whole point.
					if hangglider.use[pname] then
						if moveModelUp then
							minetest.add_entity(player:get_pos(), "hangglider:glider"):set_attach(player, "", {x=0,y=10,z=0}, {x=0,y=0,z=0})
						else
							minetest.add_entity(player:get_pos(), "hangglider:glider"):set_attach(player, "", {x=0,y=0,z=0}, {x=0,y=0,z=0})
						end
					end
					canExist = false
				end
			end
			if not canExist then
				player:set_detach()
			end
		end
		if not canExist then
			self.object:remove()
		end
	end
})]]

if minetest.global_exists("areas") then
	hangglider.flak = true
	-- chat command definition essentially copied from areas mod.
	minetest.register_chatcommand("area_flak",{
		params = "<ID>",
		description = "Toggle airspace restrictions for area <ID>",
		func = function(name, param)
			local id = tonumber(param)
			if not id then
				return false, "Invalid usage, see /help area_flak."
			end

			if not areas:isAreaOwner(id, name) then
				return false, "Area "..id.." does not exist"
					.." or is not owned by you."
			end
			local open = not areas.areas[id].flak
			-- Save false as nil to avoid inflating the DB.
			areas.areas[id].flak = open or nil
			areas:save()
			return true, ("Area's airspace %s."):format(open and "closed" or "opened")
		end
	})
end

hangglider.can_fly = function (pname, pos)
	-- Checks if the player will get shot down at the position
	if areas and hangglider.flak then
		local flak = false
		local owners = {}
		for _, area in pairs(areas:getAreasAtPos(pos)) do
			if area.flak then
				flak = true
			end
			owners[area.owner] = true
		end
		if flak and not owners[pname] then
			return false
		end
	end
	return true
end

--[[hangglider.shot_sound = function (pos)
	minetest.sound_play("hangglider_flak_shot", {
		pos = pos,
		max_hear_distance = 30,
		gain = 10.0,
	})
end ]]

local physics_attrs = {"jump", "speed", "gravity"}
local function apply_physics_override(player, overrides)
    if minetest.get_modpath("player_monoids") then
        for _, attr in pairs(physics_attrs) do
            if overrides[attr] then
                player_monoids[attr]:add_change(player, overrides[attr], "hangglider:glider")
            end
        end
    else
        player:set_physics_override(overrides)
    end
end

local function remove_physics_override(player, overrides)
    for _, attr in pairs(physics_attrs) do
        if overrides[attr] then
            if minetest.global_exists("player_monoids") then
                player_monoids[attr]:del_change(player, "hangglider:glider")
            else
                player:set_physics_override({[attr] = 1})
            end
        end
    end
end

local step_v
minetest.register_entity(":hangglider:glider", {
	visual = "mesh",
	visual_size = {x = 8, y = 8},
	collisionbox = {0,0,0,0,0,0},
	mesh = "mobs_chicken.b3d", --mobs_chicken.b3d
	immortal = true,
	static_save = false,
	textures = {"mobs_chicken.png"}, --mobs_chicken.png
	on_step = function(self, dtime)
		local canExist = false
		if self.object:get_attach() then
			local player = self.object:get_attach("parent")
			if player then
				local pos = player:get_pos()
				local pname = player:get_player_name()
				if hangglider.use[pname] then
					local mrn_name = minetest.registered_nodes[minetest.get_node(vector.new(pos.x, pos.y-0.5, pos.z)).name]
					if mrn_name then
						if not (mrn_name.walkable or mrn_name.liquidtype ~= "none") then
							canExist = true

								step_v = player:get_velocity().y
								if step_v < 0 and step_v > -3 then
									apply_physics_override(player, {speed=math.abs(step_v/2) + 0.75})
								elseif step_v <= -3 then --Cap our gliding movement speed.
									apply_physics_override(player, {speed=2.25})
								else
									remove_physics_override(player, {speed=1})
								end
								if debug then
									player:hud_change(hangglider.debug[pname].id, "text", step_v..', '..
										player:get_physics_override().gravity..', '..tostring(hangglider.airbreak[pname]))
								end
								apply_physics_override(player, {gravity=((step_v + 3)/20)})
						end
					end
				end
				if not hangglider.can_fly(pname,pos) then
				    if not self.warned then -- warning shot
						self.warned = 0
						--hangglider.shot_sound(pos)
						minetest.chat_send_player(pname, "Protected area! You will be shot down in two seconds by anti-aircraft guns!")
				    end
				    self.warned = self.warned + dtime
				    if self.warned > 2 then -- shoot down
						player:set_hp(1)
						player:get_inventory():remove_item("main", ItemStack("hangglider:hangglider"))
						--hangglider.shot_sound(pos)
						canExist = false
				    end
				end
				if not canExist then

					remove_physics_override(player, { gravity=1, jump = 1, speed = 1,})
					hangglider.use[pname] = false
					if HUD_Overlay then
					player:hud_change(hangglider.id[pname], "text", "blank.png")
					end
					--hangglider.airbreak[pname] = false
				end
			end
		end
		if not canExist then
			self.object:set_detach()
			self.object:remove()
		end
	end
})

minetest.register_on_dieplayer(function(player)
	remove_physics_override(player, {
		gravity = 1,
		jump = 1,
	})
	hangglider.use[player:get_player_name()] = false
end)


minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	remove_physics_override(player, {
		gravity = 1,
		jump = 1,
	})
	hangglider.use[pname] = false
	if HUD_Overlay then
		hangglider.id[pname] = player:hud_add({
			hud_elem_type = "image",
			text = "blank.png",
			position = {x=0, y=0},
			scale = {x=-100, y=-100},
			alignment = {x=1, y=1},
			offset = {x=0, y=0},
			z_index = -150
		})
	end
	if debug then
		hangglider.debug[pname] = {id = player:hud_add({hud_elem_type = "text",
			position = {x=0.5, y=0.1},
			text = "-",
			number = 0xFF0000}),  -- red text
			-- ht = {50,50,50},
		}
	end
	--hangglider.airbreak[pname] = false
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	hangglider.use[pname] = nil
	if HUD_Overlay then hangglider.id[pname] = nil end
	if debug then hangglider.debug[pname] = nil end
	--hangglider.airbreak[pname] = nil
end)

minetest.register_tool(":hangglider:hangglider", {
	description = "Glider",
	inventory_image = "mobs_chicken_inv.png",
	stack_max=1,
	on_use = function(itemstack, player)
		if not player or player.is_fake_player then
			-- player does not exist or is created from an automated machine (fake_player)
			return
		end
		local pos = player:get_pos()
		local pname = player:get_player_name()
		if not hangglider.use[pname] then --Equip
			--minetest.sound_play("bedsheet", {pos=pos, max_hear_distance = 8, gain = 1.0})
			if HUD_Overlay then player:hud_change(hangglider.id[pname], "text") end
			local airbreak = false
			--[[if vel < -1.5 then  -- engage mid-air, falling fast, so stop but ramp velocity more quickly
				--hangglider.airbreak[pname] = true
				airbreak = true
				local stopper = minetest.add_entity(pos, "hangglider:airstopper")
				minetest.after(0, function(stopper, player) --"Extreme Measures"
					stopper:set_pos(player:get_pos())
					stopper:get_luaentity().attach = player
					player:set_attach( stopper, "", {x=0,y=0,z=0}, {x=0,y=0,z=0})
				end, stopper, player)
			end]]
			if not airbreak then
				if moveModelUp then
					minetest.add_entity(pos, "hangglider:glider"):set_attach(player, "", {x=0,y=18,z=0}, {x=0,y=0,z=0})
				else
					minetest.add_entity(pos, "hangglider:glider"):set_attach(player, "", {x=0,y=0,z=0}, {x=0,y=0,z=0})
				end
			end
			hangglider.use[pname] = true
			apply_physics_override(player, {jump = 0})
			-- if minetest 0.4.x use this:

			-- if minetest 5.x use this:
			-- minetest.add_entity(player:get_pos(), "hangglider:glider"):set_attach(player, "", {x=0,y=10,z=0}, {x=0,y=0,z=0})
			itemstack:set_wear(itemstack:get_wear() + 255)
			return itemstack
		elseif hangglider.use[pname] then --Unequip
			if HUD_Overlay then player:hud_change(hangglider.id[pname], "text", "default_wood.png^[colorize:#0000:255") end
			hangglider.use[pname] = false
		end
	end,
	sound = {breaks = "default_tool_breaks"},
})

minetest.register_craft({
	type = "shapeless",
	output = "hangglider:hangglider",
	recipe = {"default:paper", "default:paper", "default:paper",
		"default:paper", "hangglider:hangglider", "default:paper",
		"default:paper", "default:paper", "default:paper"
	},
})

minetest.register_craft({
	output = "hangglider:hangglider",
	recipe = {
		{"mobs:chicken_feather", "wool:white", "mobs:chicken_feather"},
		{"default:stick", "", "default:stick"},
		{"", "default:stick", ""},
	}
})
