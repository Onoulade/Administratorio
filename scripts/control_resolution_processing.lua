local M = {}

function M.new(deps)
  local needs_loaded_protest_refresh = false
  local needs_loaded_working_hours_refresh = false

  local runtime_debug = deps.runtime_debug
  local process_pending_group_redirects = deps.process_pending_group_redirects or function() end

  local controller = {}

  function controller.on_load()
    needs_loaded_protest_refresh = true
    needs_loaded_working_hours_refresh = true
  end

  function controller.on_tick(event)
    local surface = game.surfaces[1]
    local runtime_snapshot, total_profiler = runtime_debug.begin_snapshot(event.tick)

    runtime_debug.run_profiled_section(runtime_snapshot, "unit_groups", function()
      deps.update_tracked_unit_group_debug(event.tick)
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "group_redirects", function()
      process_pending_group_redirects(event.tick)
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "trains", function()
      deps.trains.on_tick(event)
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "startup_cleanup", function()
      if storage.needs_startup_cleanup then
        local all_ready = true
        for _, player in pairs(game.players) do
          if not player.character then
            all_ready = false
            break
          end
        end

        if all_ready then
          storage.needs_startup_cleanup = nil
          for _, player in pairs(game.players) do
            deps.strip_weapons(player)
          end

          local ship_types = {"crash-site-spaceship", "crash-site-chest-1", "crash-site-chest-2"}
          for _, ship_name in ipairs(ship_types) do
            local ships = surface.find_entities_filtered{name = ship_name}
            for _, ship in ipairs(ships) do
              local inv = ship.get_inventory(defines.inventory.chest)
              if inv then
                inv.clear()
                if ship_name == "crash-site-spaceship" then
                  inv.insert({name = "mechanical-printer", count = 1})
                  inv.insert({name = "burner-mining-drill", count = 2})
                  inv.insert({name = "admin-station", count = 1})
                  inv.insert({name = "carbon-offset-certificate-basic", count = 3})
                end
              end
            end
          end
        end
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "evolution_warnings", function()
      for _, force in pairs(game.forces) do
        deps.warn_force_about_evolution_complaints(force)
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "working_hours_refresh", function()
      if needs_loaded_working_hours_refresh then
        if deps.working_hours.is_enabled() then
          deps.working_hours.rebuild_registry()
        end
        needs_loaded_working_hours_refresh = false
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "protest_refresh", function()
      if storage.needs_protest_refresh or needs_loaded_protest_refresh then
        deps.biters.refresh_protest_notifications()
        storage.needs_protest_refresh = nil
        needs_loaded_protest_refresh = false
      end
    end)

    if deps.working_hours.is_enabled() then
      runtime_debug.run_profiled_section(runtime_snapshot, "working_hours", function()
        deps.working_hours.update_managed_buildings()
      end)
    end

    local desks = {}
    local powered_desks = desks
    local desks_by_surface = {}
    runtime_debug.run_profiled_section(runtime_snapshot, "desk_cache", function()
      desks = deps.get_cached_desks()
      powered_desks = desks
      desks_by_surface = {}
      for _, desk in ipairs(powered_desks) do
        if desk and desk.valid and desk.surface and desk.surface.valid then
          local bucket = desks_by_surface[desk.surface.index]
          if not bucket then
            bucket = {surface = desk.surface, desks = {}}
            desks_by_surface[desk.surface.index] = bucket
          end
          bucket.desks[#bucket.desks + 1] = desk
        end
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "achievements", function()
      if not storage.achievements.department_of_everything and #powered_desks >= 10 then
        storage.achievements.department_of_everything = true
        for _, player in pairs(game.connected_players) do
          player.unlock_achievement("department-of-everything")
        end
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "registration", function()
      for _, bucket in pairs(desks_by_surface) do
        deps.biters.process_walk_in_registration(bucket.surface, bucket.desks, runtime_snapshot and runtime_snapshot.sections or nil)
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "resolutions", function()
      deps.biters.process_resolutions(powered_desks)
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "frustration", function()
      local processed_surfaces = {}
      for _, bucket in pairs(desks_by_surface) do
        deps.biters.process_frustration_and_protests(bucket.surface)
        processed_surfaces[bucket.surface.index] = true
      end

      for _, info in pairs(storage.waiting_biters or {}) do
        local tracked_surface = nil
        if info and info.entity and info.entity.valid then
          tracked_surface = info.entity.surface
        elseif info and info.last_known_surface_index then
          tracked_surface = game.get_surface(info.last_known_surface_index)
        end

        if tracked_surface and not processed_surfaces[tracked_surface.index] then
          deps.biters.process_frustration_and_protests(tracked_surface)
          processed_surfaces[tracked_surface.index] = true
        end
      end
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "calmed_spawners", function()
      deps.biters.process_calmed_spawners(event.tick)
    end)

    runtime_debug.run_profiled_section(runtime_snapshot, "circuit", function()
      deps.biters.update_circuit_signals(desks)
    end)

    if runtime_snapshot and total_profiler then
      runtime_debug.run_profiled_section(runtime_snapshot, "debug_finalize", function()
        runtime_snapshot.counts = deps.collect_runtime_debug_counts(desks)
      end)
      runtime_debug.complete_snapshot(runtime_snapshot, total_profiler)
    end
  end

  return controller
end

return M
