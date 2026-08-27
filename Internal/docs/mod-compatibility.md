# Mod Compatibility Engine

How Administratorio integrates with other mods, and how to add an integration
of your own without editing core logic.

Everything lives under `compat/`:

```
compat/
  hooks.lua                 the engine: register / resolve / collect
  init.lua                  the static list of compat modules and their stages
  factorissimo/
    data.lua                data-stage half (prototype changes)
    runtime.lua             control-stage half (remote calls, hook answers)
```

## The idea

Core modules never name another mod. Instead they read a **hook point** — a
named question with a default answer of their own:

```lua
-- scripts/working_hours.lua
local outside, dark = hooks.resolve("time_of_day_surface", surface, position)
if outside == nil then return surface, false end   -- nobody answered
```

A compat module answers that question at load time:

```lua
-- compat/factorissimo/runtime.lua
hooks.register("time_of_day_surface", function(surface, position)
  if not M.available() then return nil end        -- "not my case"
  ...
  return outside, unlit
end)
```

With no compat module registered, `resolve` returns `nil` and the core keeps
its own answer, so the vanilla path costs one table lookup and stays exactly as
it was before the hook existed.

The seam in the core is the only part that cannot be avoided: Lua locals cannot
be patched from outside a file, `script.on_event` allows one handler per event
per mod, and Factorio cannot enumerate a directory. So extension points are
authored, not injected. **A new mod that fits an existing point costs zero lines
outside `compat/`. A new *kind* of interference costs one seam.**

## The two kinds of hook

### `resolve(point, ...)` — ask for one answer

Handlers are tried in registration order; the first one returning a non-`nil`
first value wins, and its second return value comes along. `nil` means "not my
case", which is what lets several mods share one point without fighting.

Use it for a decision that depends on runtime state.

### `collect(point, base)` — merge sets once, at load time

Every handler returns a table; all of them are merged into `base`, which is
returned. The result is a plain table, so a hot loop keeps indexing it directly
with no call overhead.

Use it for whitelists, blacklists, name sets — anything read on every tick.

Because `collect` runs while the core module is loading, registration has to
happen first. `compat.init` is required at the top of `control.lua` for exactly
that reason, and registering into a point that was already read raises an error
instead of being silently dropped — a silent misordering would silently disable
compatibility.

## Existing hook points

| Point | Kind | Question | Answer |
| --- | --- | --- | --- |
| `time_of_day_surface` | `resolve` | Which surface carries the real time of day for a building at `(surface, position)`, and is the spot dark whatever that surface says? | `surface, dark` — or `nil` to fall through |
| `tube_traversable_entities` | `collect` | Which foreign entities may a pneumatic tube network walk through? | `{[entity_name] = true}` |
| `recipe_required_form` | `resolve` | Which paperwork form does a compatible recipe require? | `form` — or `nil` to keep the core rule |
| `recipe_batch_multiplier` | `resolve` | What batch multiplier does a compatible recipe use? | `multiplier` — or `nil` to keep the core rule |

`time_of_day_surface` exists because a mod can freeze the daytime of a surface
it owns. Factorissimo does: a factory floor sits at noon with the interior
lights upgrade and at midnight without, both with `freeze_daytime`, so a
day-gated building inside a factory would otherwise never see night. The
Factorissimo handler walks out to the enclosing factory's outside surface,
through nested factories, and reports a factory without the lights upgrade as
dark.

`tube_traversable_entities` exists because widening a foreign entity to accept
the `pneumatic-forms` connection category — which `compat/factorissimo/data.lua`
does to the factory wall pumps — also has to tell the tube BFS that the entity
is safe to walk through. Without that, a water pipe behind such an entity would
drag the whole fluid grid into the tube network.

## Adding your own compatibility

1. **Create `compat/<mod>/`.** Use `data.lua` for prototype changes and
   `runtime.lua` for control-stage code. Keep them separate files: the two
   stages never share a Lua state, and a single file would need stage guards.

2. **Register the directory in `compat/init.lua`:**

   ```lua
   local COMPAT = {
     {mod = "factorissimo", stages = {data = true, runtime = true}},
     {mod = "yourmod",      stages = {runtime = true}},
   }
   ```

   Only declare the stages whose files actually exist; a missing file is a load
   error, on purpose.

3. **Gate the module on its mod being present.** Do it inside the module, never
   in `init.lua`. Both of these are fine:

   ```lua
   if not (data.raw.pump and data.raw.pump["their-entity"]) then return end  -- data stage
   if not remote.interfaces["theirmod"] then return nil end                  -- runtime
   ```

   When you call a remote interface, check that the methods you use are actually
   in it, not just the interface itself — an older release of the same mod may
   not expose them, and a missing method is a crash inside `remote.call`.

4. **Answer a hook point** with `hooks.register(point, handler)`. Return `nil`
   from a `resolve` handler for any case you do not claim.

5. **If no point fits,** add one. That is the only change a compat module may
   ask of a core file:

   - Pick a name describing the *question*, not the mod. `time_of_day_surface`,
     not `factorissimo_interior`.
   - Put the call at the place where the decision is actually made, and keep the
     vanilla answer in the core as the fallback.
   - Document the point in the table above.

6. **Write a test.** `tests/test_factorissimo_compat.lua` is the pattern: mock
   `remote`, assert what the handler answers, and assert that requiring the
   module registers it. `tests/test_compat_hooks.lua` covers the engine itself.
   Tests that load a core module reading a `collect` point must load
   `compat.init` first, the same order `control.lua` uses.

## Things the engine deliberately does not do

- **No event dispatcher.** Factorissimo has one (`lib/events.lua`) because its
  compat files need their own event subscriptions. None of ours do yet. When one
  does, the dispatcher is about twenty lines — add it then.
- **No mod-presence helper.** Each module already has a stricter check available
  to it (a prototype, a remote interface), and a shared `is_active()` would just
  be a weaker duplicate.
- **No automatic discovery.** `compat/init.lua` is a hand-maintained list
  because the data stage cannot read a directory. Keeping the runtime list in
  the same file keeps both stages honest about what exists.
