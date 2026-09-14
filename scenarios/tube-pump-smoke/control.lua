-- Engine integration test: --scenario2map administratorio/tube-pump-smoke
local pneumatic = require("__administratorio__/scripts/pneumatic")
local C = require("__administratorio__/scripts/constants")

script.on_init(function()
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  pneumatic.ensure_storage()
  for _, direction in ipairs({0, 4, 8, 12}) do
    local pump = surface.create_entity{name = "tube-pump", position = {direction * 4 + 0.5, 0}, direction = direction, force = "player"}
    assert(pump and pump.direction == direction)
    pneumatic.add_tube_pump_supports(pump)
    local bounds = pump.bounding_box
    local width = bounds.right_bottom.x - bounds.left_top.x
    local height = bounds.right_bottom.y - bounds.left_top.y
    assert((direction % 8 == 0 and height > width) or (direction % 8 == 4 and width > height), "footprint did not rotate")
    local entry = storage.tube_pumps[pump.unit_number]
    for index, port in ipairs(entry.ports) do
      local dx = port.position.x - pump.position.x
      local dy = port.position.y - pump.position.y
      local pipe = surface.create_entity{name = "pneumatic-pipe", position = {pump.position.x + dx * 3, pump.position.y + dy * 3}, force = "player"}
      assert(pipe)
      local connections = port.fluidbox.get_connections(1)
      assert(#connections == 1 and connections[1].owner == pipe, "port connectivity failed: " .. direction .. "/" .. index)
    end
    pneumatic.rebuild_network_cache()
    local networks = storage.tube_pump_network_cache[pump.unit_number]
    assert(networks[1] ~= networks[2], "pump short-circuited networks")
    local a, b, blocked = C.PNEUMATIC_ITEMS[1], C.PNEUMATIC_ITEMS[2], C.PNEUMATIC_ITEMS[3]
    pump.use_filters = true
    pump.set_filter(1, a)
    pump.set_filter(2, b)
    storage.tube_signals[networks[1]] = {[a] = 1, [b] = 1, [blocked] = 1}
    pneumatic.on_pneumatic_tick()
    pneumatic.on_pneumatic_tick()
    assert(storage.tube_signals[networks[2]][a] == 1 and storage.tube_signals[networks[2]][b] == 1, "multi-filter transfer failed")
    assert(storage.tube_signals[networks[1]][blocked] == 1, "filter leaked")
    pneumatic.rebuild_network_cache()
    assert(storage.tube_signals[networks[2]][a] == 1, "pump-only pool lost on rebuild")
    assert(pump.rotate(), "native rotate refused")
    -- Like the vanilla 1x2 pump, a placed entity reverses by 180 degrees;
    -- quarter turns are selected while placing on the alternate tile grid.
    assert(pump.direction == (direction + 8) % 16, "native rotate wrong direction")
    local vanilla = surface.create_entity{name = "pump", position = {direction * 4 + 0.5, 10}, direction = direction, force = "player"}
    assert(vanilla.rotate() and vanilla.direction == pump.direction, "rotation differs from vanilla pump")
    vanilla.destroy()
    pneumatic.refresh_tube_pump_supports(pump)
    assert(not entry.ports[1].valid and not entry.ports[2].valid, "stale supports survived rotation")
    pneumatic.delete_tube_pump_supports(pump)
    pump.destroy()
  end
  log("TUBE PUMP ENGINE TESTS PASSED: all four directions, native rotation, footprints, separate connections, two filters, pool retention, support cleanup")
end)
