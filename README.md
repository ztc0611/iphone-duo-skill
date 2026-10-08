# iPhone Duo agent skill

A portable skill for building adaptive iPhone Duo app layouts and testing fold behavior in the simulator. It covers display-aware layout, hinge state, and simulator checks.

## Install

Copy the entire `iphone-duo` directory, including `SKILL.md` and `references/`, into your agent's supported skills directory. If you already have a customized `iphone-duo` skill, preserve it and review the new files before replacing anything.

For Codex, the default personal location is `~/.codex/skills/iphone-duo`. Invoke it with `$iphone-duo`, or let skill discovery select it for relevant requests.

For Claude Code, place the directory at `~/.claude/skills/iphone-duo` for personal use across projects, or at `.claude/skills/iphone-duo` in a project. Invoke it with `/iphone-duo`; Claude Code can also load it automatically when relevant. Cloud sessions don't read `~/.claude/skills`; to use it there, commit it to the repository's `.claude/skills/` or enable it for your claude.ai account. See the [Claude Code skills documentation](https://code.claude.com/docs/en/skills).

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by Apple. iPhone and Xcode are trademarks of Apple Inc.
