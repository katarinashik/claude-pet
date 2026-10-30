# Claude desktop pet

A little pixel Claude that sits in the bottom-right corner of the screen Katya picks (right-click → Screen, remembered in `%USERPROFILE%\ClaudePet\screen.txt`), always on top of every window, codes on a laptop, does little activities, and reacts to Claude Code through hooks. He walks along the taskbar only when she picks another screen. He no longer hides or moves when a window covers him: she wants to see him all the time. One PowerShell 5.1 + WPF script, no other dependencies.

## Files

- `ClaudePet.ps1`: the pet. Source of truth; edit here, then install.
- `ClaudePet.ico`: his icon for the desktop button, drawn by `tools/Make-Icon.ps1`.
- `Start-ClaudePet.vbs`: launcher without a console window. Starts the pet again after 5 s if it closes by itself (exit code not 0), at most 20 times. "Bye, Claude" exits 0 and stops it.
- `tools/Make-Storyboard.ps1`: renders a pose as a picture from the real script, without opening the pet.
- `frames/<pose>.ps1`: the storyboard frames of each pose (calls to the `Set-*` art functions plus `Shot 'name'`).
- `storyboards/`: the approved storyboards, rendered by the script only.
- Local only, never in the repo (`.gitignore`): `references/` (pictures by other people that Katya collected as inspiration; copyrighted, so never put them, or a storyboard that shows them, on GitHub) and `archive/`.
- `archive/`: old test copies and abandoned art directions. Not used.

## Git

The project is a git repo. `main` is public on GitHub: https://github.com/katarinashik/claude-pet (remote `origin`). Commits use her private GitHub noreply email (set in the repo config), never her work email. The local branch `private-history` keeps the old history (work email, archive, references): never push it. Push `main` after each approved change. GitHub CLI holds two accounts and the work one (katanalyst555) is normally active: run `gh auth switch --user katarinashik` before a push and `gh auth switch --user katanalyst555` after it. Git for Windows is installed for this user only and isn't on PATH in every shell: use `& "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"`. Commit after each approved and installed change.

## Install and run

```powershell
Copy-Item .\ClaudePet.ps1, .\Start-ClaudePet.vbs, .\hooks\stop-hook.ps1, .\ClaudePet.ico "$env:USERPROFILE\ClaudePet" -Force
# stop the launcher first, or it brings the old pet back
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*Start-ClaudePet*' -or $_.CommandLine -like '*\ClaudePet\ClaudePet.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
# start him through Explorer, never Start-Process from a Claude tool: then he is a child of the Claude app and dies with its session
explorer.exe "$([Environment]::GetFolderPath('Desktop'))\Claude Pet.lnk"
```

- The install folder is `%USERPROFILE%\ClaudePet`, not `%LOCALAPPDATA%`: the Claude desktop app is an MSIX package, so whatever its tools write under `%LOCALAPPDATA%` lands in its sandbox (`%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Local`), which Windows outside the app can't see. That gave "Can not find script file" at logon and a pet that vanished when the app restarted.
- The button: `Claude Pet` on the desktop and in the Start menu (wscript + `Start-ClaudePet.vbs`, icon `ClaudePet.ico` from `tools/Make-Icon.ps1`). Clicking it while he runs does nothing (the mutex).
- Starts with Windows: `Startup-ClaudePet.vbs` is copied to `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Claude Pet.vbs`. It waits up to 2 min for the installed launcher and then starts it. A plain shortcut once ran before the launcher could be read and showed "Can not find script file".
- `%USERPROFILE%\ClaudePet\pet.log`: starts, stops ("bye" or "closed without bye") and errors inside a tick. Look here first when he is missing.
- Test run without touching the installed pet: `powershell -Sta -NoProfile -File .\ClaudePet.ps1 -TestSeconds 30 -Log <file>`. It writes one state line every 6 ticks. For fast tests, copy the script and set `$MIN` to a few ticks, so the tiers and the calm pass in seconds, or set one `next...` counter to a small number. Rename the mutex `Local\ClaudeDesktopPet` and the `PetWin` type in the copy, so it runs next to the real pet.

## Claude Code hooks (in `~/.claude/settings.json`)

They write the time into files that the pet checks about once a second:

- `UserPromptSubmit`, and `PostToolUse` with matcher `*` → `busy.txt`: he types faster between poses. Poses keep coming while Claude Code works: Katya watches him exactly then.
- `Notification` (`permission_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input`) → `wait.txt`: he drops everything, gets up from a nap, the music or the beach, and waves with a "!".
- `Stop` → `hooks/stop-hook.ps1` (installed to `%USERPROFILE%\ClaudePet\stop-hook.ps1`): writes `done.txt` (he waves a checkered flag, at most once a minute), except after a turn that a background agent's report started (`origin.kind` `task-notification` or `peer` on the turn's first message) and that didn't call `wrap_up`: that session is still waiting for its other agents. It also writes `ask.txt` only when that turn ended with a question for Katya: `wrap_up` with an `ask`, `AskUserQuestion`, or last text ending in "?". After the flag he then waves "!" for a minute. Stop fires for every session, scheduled routines included, which is why a plain "every turn" rule gave false calls.

## Settings, weather, the newspaper, the popcorn (acts)

- `%USERPROFILE%\ClaudePet\settings.json` (optional, never in the repo): `place`, `latitude`, `longitude`, `weatherModel`, `newsLock`. Defaults: Lyon, Open-Meteo `best_match`, no newspaper. Katya's own file points at her office and her scraping routine's lock file; keep work-specific places and paths there, not in the code.

- Every 15 min `Weather-Tick` asks Open-Meteo (free, no key) for the place in settings.json, in a background runspace. Empty or broken answers are ignored (they once read as 0 °C and brought the cold scene); a request hanging over 2 min is dropped and asked again.
- `Get-WxKind` picks one scene, strongest first: storm, snow, rain, drizzle, wind (35 km/h+), cold (3 °C or less), heat (25 °C+), fog (only real fog, codes 45/48), cloudy (partly cloudy or overcast, unless the sun gets through: direct radiation ≥ 40 % of all daylight); clear = nothing. Katya checks against her window: models lag behind morning mist clearing, hence the sun-share rule. Airport METARs (Bron, Saint-Exupéry) were checked too and said the same as the models. pet.log gets the first answer and every change.
- `Ambient-Tick`: while that weather lasts, its background shows (flakes, drops, mist, sun, frost, gusts, a drifting cloud, storm strikes). No props in his hands.
- Acts (`$acts`, played by `Act-Tick`, one step list each, same beats as `frames/<scene>.ps1`): the full weather scene 1–3 min after the weather changes, then every 20–40 min while it lasts; `news` for the whole time the `newsLock` file exists (Katya: her twice-a-day scraping routine creates it at its start and deletes it at its end); a lock older than 2 h counts as left over (Katya wants to see the routine working, not only that it published); `pop` when Claude Code has been working 10 min in a row (all chats together; Katya first had 3.5 min and chose not to count per chat): a bowl of about a minute, then 3–5 min of other poses, then another bowl while it still works (Katya found 10 minutes of popcorn in one go far too long). All are in the menu too (Do something → Weather ▸, Newspaper, Popcorn) and on double click.
- Drizzle (yellow raincoat) and rain (umbrella, puddle jump) stay two separate scenes: Katya chose that.

## How often things happen

- Typing at the laptop is his normal state. After any pose ends, `$S.calm` gives 2 minutes of plain typing before the next random pose (`$MIN` = timer ticks in a minute).
- Often, every 4–8 min of typing: coffee, sunglasses. Sometimes, every 10–20 min: daydream, bug hunt, detective, music. Rare, every 45–90 min: nap. Katya first had longer gaps (8-minute calm, 20 min to 8 h) and found him too still: she likes to see him change poses.
- By the clock, from the day's plan in `New-MealDay`: croissant, sandwich, payday (once a day in the last week), wizard (one day in five), beach (Friday 16:00–17:30).
- Events: the flag when Claude Code finishes, the "!" wave when it waits for her.
- Hello and goodbye (`storyboards/hello.png`, `goodbye.png`): at every start he walks in from the right edge of his screen with the closed laptop under his arm (`$laptopTuck`), waves hi (`Greet-Tick`), puts it down and opens it. "Bye, Claude" (`Start-Bye`, `Bye-Tick`): he closes the lid, waves, takes the laptop under his arm and walks off the right edge; only then the pet closes. Any walk (a screen change too) carries the laptop under his arm.

## Poses tied to the clock

- Coffee is more likely 8–11, the nap 13–15, music after 18 (their random timers count down twice as fast then).
- Meals run once a day each, by the clock, not by a random timer (`Meal-Tick`): a croissant at a random minute 8:30–10:45 (until 11:00), a sandwich 12:20–12:50 (until 13:30). He waits for a free moment. Each meal ends with the broom cleanup.
- Payday: once a day at a random minute 10:00–17:00, only in the last 7 days of the month. Wizard: 9:30–17:30 on about one day in five. Beach: Friday 16:00–17:30. All three wait for a free moment, until 19:00. What already ran today is kept in `%USERPROFILE%\ClaudePet	oday.txt` (`Mark-Done`), so a restart doesn't bring an overdue payday or meal straight away: it used to, after every restart.

## How the art works

- The look is approved, so don't redesign it. The style is the flat orange pixel Claude: `$PX` screen pixels per art pixel (now 4), black laptop with a white `<>` logo at lower left, the right arm down to the keyboard, ears as side bumps. Angle as in `storyboards/typing-angle.png`.
- The grid is `$GW` x `$GH` art pixels (22 x 17). `$OY` (9) free rows above the head hold hats, bubbles, notes and "!". Negative rows go up into that space.
- `Add-Px parent x y w h brush` draws one rectangle.
- `Add-Art parent x0 y0 @('rows') @{ letter = brush }` turns text rows into rectangles; `.` is empty.
  - Map keys are case-insensitive, so letters in one map must differ ignoring case.
- `$upper` holds the body, eyes and anything that moves with the body bob. `$scene` holds legs, laptop and things that don't move.
- Every activity is a set of hidden elements plus `Set-*` functions that show and move them. Add art before the `# "!" when you catch him` line, and functions before `function Set-Sparkle(`.

## Adding a pose

Katya's workflow:

1. Draw the art.
2. Write `frames/<pose>.ps1`.
3. Run `tools/Make-Storyboard.ps1`.
4. Show her the picture and wait for her yes.
5. Only then add the behaviour, test it, and install.

Do one pose at a time.

A pose's behaviour touches these places (search for an existing pose, for example `pay`/`Pay-Tick`, and copy its pattern):

- **The `$S` state table:** its counter and its random timer `next...`.
- **A `...-Tick` function:** it returns `$true` while the pose runs. It's called in the coding branch next to `Coffee-Tick`. Poses that leave the laptop (nap, music, sun) are a `$S.state` of their own instead.
- **The guards:** while it runs, other poses don't start on their own. Add `-and $S.<pose> -eq 0` to their start conditions.
- **The shared "end everything" line:** add `End-<Pose>` to it. It's used before a nap, music, the beach, packing and the flag.
- **Busy freeze:** add its `next...` counter to the list frozen while Claude Code is busy.
- **Hover:** a branch in the hover chain.
- **Dragging:** end it in the mouse-drag handler.
- **Menu:** a menu item, added to the `Do something` submenu.
- **Eyes:** if the pose hides or replaces the eyes, add it to `$eyesFree`, otherwise the normal eyes come back on top.

## Pitfalls already hit

- **Comments on a brush line:** many lines define several brushes separated by `;`. A `#` comment put after the first one silently comments out the rest, and those props render as nothing (it happened twice: the ice cream and the fog lamp). Put the comment on its own line above.

- **Variable names:** PowerShell names are case-insensitive. `$s` is `$S` (the whole state), `$p` is `$P`, `$x` is `$X`. Never use one-letter names that match a global.
- **`[Math]::Min(1, x)`:** picks the int overload. Write `1.0`.
- **Returning an array:** a function returns an array unrolled. Use `, $array`.
- **CRLF:** files are written with `\n`. Normalise CRLF before string `Replace`.
- **Old artwork:** don't trace or convert AI reference pictures (white halos, inconsistent pixels). Redraw in the approved style.

## Katya's taste, from her feedback

- **Pace:** calm, not hyperactive. No white flash on the keys while typing.
- **Overlap is fine:** a held object may cover part of the body or an eye; that's natural. Don't shrink a prop just to keep the eyes clear.
- **Readability:** props must read at a glance. A thing must be held in a visible hand, never float next to an ear. Outlined shapes read better than flat ones.
- **Language:** she talks in Russian in chat; code and comments are in English.
