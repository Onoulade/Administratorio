# Contributing

## Release Automation

Releases are handled by the manually dispatched GitHub Actions release workflow on
`main`. When starting the workflow, enter the exact version to publish, such as
`0.4.4` or `0.5.0`. The workflow then:

- update `info.json`;
- prepend generated Factorio-format notes to `changelog.txt` from commits since
  the previous version tag;
- commit the release metadata back to `main`;
- create an annotated `vX.Y.Z` tag;
- package the mod zip with `git archive`;
- publish the GitHub release and upload the mod when `FACTORIO_TOKEN` is set.

Do not edit release versions by hand for normal releases. Choose the intended
version in the manual workflow input instead. The workflow will fail if that tag
already exists or if `info.json` is already at the requested version.

## Beta Release Posture

Administratorio is currently in beta. Contributions should assume the full
progression arc is playable, but balance, compatibility, translation coverage,
runtime migrations, and late-game polish are still fair game for iteration.
Player-facing changes should be described clearly in commit subjects because they
feed the Factorio changelog.

## Validation

Run the fast Lua and Python checks after every change:

```sh
./tests/run-tests.sh --repo-root .
```

Before release, provide a Factorio 2.0 binary to add the real prototype dump,
planet-escape analysis, supported-configuration matrix, and control-stage runtime
scenario:

```sh
./tests/run-tests.sh --repo-root . \
  --factorio-bin /path/to/factorio
```

The runtime scenario starts a temporary local headless server, runs real build
events, and shuts it down after its assertions pass. Its environment must permit a
temporary local UDP socket.

Gameplay values repeated in the internal reference are generated from
`prototypes/shared/gameplay_facts.lua`. After changing those facts, refresh only the
marked factual sections and review the result:

```sh
lua tools/generate-reference-docs.lua
lua tools/generate-reference-docs.lua --check
```

The normal test suite performs the generated-section check automatically.

## Commit Structure

Use Conventional Commits:

```text
type(optional-scope): short imperative summary
```

Examples:

```text
feat(biterport): add night dispatch warnings
balance: reduce early paperwork cost
fix(pneumatic): preserve circuit disabled state
```

Breaking changes should still be called out explicitly in the commit subject or
body, but they do not choose the release number automatically. Pick the intended
version when running the release workflow.

## Release Types

These types group generated changelog entries; they do not choose the version.

- `feat` or `feature`: listed under Features.
- `fix`: listed under Bugfixes.
- `info`: listed under Changes.
- `gui`: listed under Gui.
- `balance`: listed under Balancing.
- `perf` or `performance`: listed under Optimizations.
- `compat` or `compatibility`: listed under Compatibility.
- `graphics`: listed under Graphics.
- `sound`: listed under Sounds.
- `locale`: listed under Locale.
- `translate`: listed under Translation.
- `control`: listed under Control.
- `docs`: listed under Docs.
- `internal`, `test`, `chore`, `ci`, or `build`: listed under Internal.
- `other` or non-conventional subjects: listed under Changes.

Use scopes for the part of the mod touched, such as `recipes`, `technology`,
`field-office`, `biterport`, `locale`, or `tests`. Keep the subject concise and
player-facing when it will appear in the changelog.
