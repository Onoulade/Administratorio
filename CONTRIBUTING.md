# Contributing

## Release Automation

Releases are handled by the manually dispatched GitHub Actions release workflow on
`main`. The workflow installs
`semantic-release`, `semantic-release-factorio`, and the conventional changelog
tools, then uses `.releaserc` to:

- choose the next version from commit history;
- update `info.json`;
- prepend generated Factorio-format notes to `changelog.txt`;
- package the mod zip;
- publish the GitHub release and upload the mod when `FACTORIO_TOKEN` is set.

Do not edit release versions by hand for normal releases. Let the release workflow
advance the version and changelog from the commit history.

## Beta Release Posture

Administratorio is currently in beta. Contributions should assume the full
progression arc is playable, but balance, compatibility, translation coverage,
runtime migrations, and late-game polish are still fair game for iteration.
Player-facing changes should be described clearly in conventional commit subjects
because they feed the Factorio changelog.

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

Breaking changes must either add `!` after the type or include a `BREAKING CHANGE:`
footer:

```text
feat!: require Factorio 2.1
```

## Release Types

- `feat` or `feature`: minor release, listed under Features.
- `fix`: patch release, listed under Bugfixes.
- `info`: patch release, listed under Info.
- `gui`: patch release, listed under Gui.
- `balance`: patch release, listed under Balancing.
- `perf` or `performance`: patch release, listed under Optimizations.
- `compat` or `compatibility`: patch release, listed under Compatibility.
- `graphics`: patch release, listed under Graphics.
- `sound`: patch release, listed under Sounds.
- `locale`: patch release, listed under Locale.
- `translate`: patch release, listed under Translation.
- `control`: patch release, listed under Control.
- `docs`: patch release, listed under Docs.
- `internal` or `test`: patch release, listed under Internal.
- `other`: patch release, listed under Changes.

Use scopes for the part of the mod touched, such as `recipes`, `technology`,
`field-office`, `biterport`, `locale`, or `tests`. Keep the subject concise and
player-facing when it will appear in the changelog.
