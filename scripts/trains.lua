-- Train station transit permit logic (Visible Chest)
-- Auto-places a transit-permit-chest overlapping each train stop.
-- Destination Station requires a permit. Limit is equal to permits in chest.
-- Train consumes one transit-authorization ON ARRIVAL at the station.

local M = {}

local CHEST_NAME = "transit-permit-chest"
local FORM_NAME = "transit-authorization"

-- Syncs a single station's train limit with its chest contents
local function sync_station(station_data)
    local station = station_data.station
    local chest = station_data.chest

    if not station.valid or not chest.valid then return false end

    -- ALWAYS lock the circuit network so signals cannot override the limit
    -- Using get_control_behavior() instead of get_or_create prevents performance lag
    local behavior = station.get_control_behavior()
    if behavior then
        behavior.circuit_enable_disable = false
        behavior.set_trains_limit = false
    end

    -- We leave station.operable untouched (true) so the player can rename it and change colors.
    -- If they try to manually slide the train limit bar or tick the circuit network boxes, 
    -- this script will stubbornly overwrite their changes on the very next second.

    local inv = chest.get_inventory(defines.inventory.chest)
    local form_count = inv and inv.get_item_count(FORM_NAME) or 0

    if form_count > 0 then
        -- Open the station and set limit to how many forms it has
        station.trains_limit = form_count
    else
        -- Close the station
        station.trains_limit = 0
    end
    return true
end

-- Create the chest and register it to storage
local function setup_station(station)
    if not station or not station.valid then return end

    storage.stations = storage.stations or {}

    -- Check if a chest already exists (e.g., from ghost revival)
    local chest = station.surface.find_entities_filtered{
        name = CHEST_NAME,
        position = station.position,
        radius = 1
    }[1]

    if not chest then
        chest = station.surface.create_entity{
            name = CHEST_NAME,
            position = station.position,
            force = station.force,
        }
    end

    if chest then
        chest.destructible = false
        chest.minable = false -- Prevent players from manually picking up the chest

        -- Optional: Filter the chest so it only accepts the form
        local inv = chest.get_inventory(defines.inventory.chest)
        if inv and inv.supports_filters() then
            for i = 1, #inv do
                inv.set_filter(i, FORM_NAME)
            end
        end

        local station_data = {
            station = station,
            chest = chest
        }
        storage.stations[station.unit_number] = station_data
        sync_station(station_data)
    end
end

-- --------------------------------------------------------
-- EVENT HANDLERS (To be called from control.lua)
-- --------------------------------------------------------

function M.on_built(entity)
    -- control.lua is passing the entity directly, not the event table
    if entity and entity.valid and entity.type == "train-stop" then
        setup_station(entity)
    end
end

function M.on_removed(entity)
    -- control.lua is passing the entity directly, not the event table
    if entity and entity.valid and entity.type == "train-stop" then
        storage.stations = storage.stations or {}
        local station_data = storage.stations[entity.unit_number]

        if station_data and station_data.chest and station_data.chest.valid then
            -- Spill forms on the ground before destroying the chest
            local inv = station_data.chest.get_inventory(defines.inventory.chest)
            if inv then
                for i = 1, #inv do
                    local stack = inv[i]
                    if stack and stack.valid_for_read then
                        entity.surface.spill_item_stack{
                            position = station_data.chest.position,
                            stack = stack,
                            enable_looted = true,
                            force = entity.force
                        }
                    end
                end
            end
            station_data.chest.destroy()
        end
        storage.stations[entity.unit_number] = nil
    end
end

-- Replaces on_tick. Run this via script.on_nth_tick(60, trains.on_nth_tick)
-- This runs once per second instead of 60 times a second. Huge performance boost!
function M.on_tick(event)
    storage.stations = storage.stations or {}
    for unit_number, station_data in pairs(storage.stations) do
        local is_valid = sync_station(station_data)
        if not is_valid then
            storage.stations[unit_number] = nil -- Cleanup if station was destroyed via script
        end
    end
end

-- Consume permit when the train ARRIVES
function M.on_train_changed_state(event)
    local train = event.train
    
    -- When the train physically arrives at the station and starts waiting
    if train.state == defines.train_state.wait_station then
        local station = train.station
        if station and station.valid then
            storage.stations = storage.stations or {}
            local station_data = storage.stations[station.unit_number]

            if station_data and station_data.chest and station_data.chest.valid then
                local inv = station_data.chest.get_inventory(defines.inventory.chest)
                
                if inv and inv.get_item_count(FORM_NAME) > 0 then
                    -- Consume 1 permit!
                    inv.remove({name = FORM_NAME, count = 1})

                    -- Check if it just ran out of permits
                    if inv.get_item_count(FORM_NAME) == 0 then
                        for _, player in pairs(game.connected_players) do
                            player.create_local_flying_text{
                                text = {"", "[color=red]", station.backer_name or "Station", ": Out of transit authorizations![/color]"},
                                position = station.position,
                                color = {r = 1, g = 0.2, b = 0.2},
                                time_to_live = 120,
                            }
                        end
                    end

                    -- Immediately sync the station so another train doesn't path to it 
                    -- if the limit just dropped to 0
                    sync_station(station_data)
                end
            end
        end
    end
end

function M.on_init()
    storage.stations = {}
    for _, surface in pairs(game.surfaces) do
        local stations = surface.find_entities_filtered{type = "train-stop"}
        for _, station in ipairs(stations) do
            setup_station(station)
        end
    end
end

-- Add aliases so existing calls in control.lua don't crash
M.init_all_stations = M.on_init
M.handle_state_change = M.on_train_changed_state

return M