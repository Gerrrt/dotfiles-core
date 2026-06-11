# examples/ — opt-in showcases (NOT wired into bootstrap)

Nothing in this directory is symlinked by `bootstrap.sh` (it only links the
specific paths listed in `wire_links()`). These are reference configs you can
copy, adapt, or try out without touching your live setup.

| File                     | What it shows                                                                                                                                  | How to try it                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `mise.project.toml`      | mise as more than a runtime manager: `[env]` (dotenv/PATH/secrets), `[tasks]`, `[hooks]` (a direnv replacement), and non-runtime tool backends | copy into a project as `mise.toml`, then `mise trust && mise install`                |
| `starship.showcase.toml` | a louder starship variant: right-aligned prompt via `fill` + `right_format`, a `[custom]` module, `sudo`/`battery`/`shell`, palette switching  | `STARSHIP_CONFIG=~/dotfiles-MacBook/examples/starship.showcase.toml starship prompt` |

> These were generated as a "here's the potential" exploration. The real,
> agreed-on changes (direnv / kubernetes / git_metrics) already live in
> `core/starship/starship.toml`. Treat everything here as a menu, not a diff.
