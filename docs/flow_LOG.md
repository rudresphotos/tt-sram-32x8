# Flow log (timing sign-off + reproducible build)

What was run, why, and the result. Newest entries at the bottom. Every number here comes from a command
whose output is shown or saved next to it.

## 2026-11-16: Setup, day 0

### 1. Unpacked the hand-over pack
- **What:** `unzip ~/Downloads/tt_sram_timing_signoff_pack.zip` into `~/tt_signoff_pack/`.
- **Why:** it holds the docs, the try9 outputs (reference results) and the two git bundles.
- **Result:** read `README_START_HERE.md` and `context/PROJECT_HANDOVER.md` in full.

### 2. Checked the machine
- **What:** `uname -m; sysctl -n machdep.cpu.brand_string hw.memsize hw.ncpu; df -h ~`
- **Result:** `arm64`, `Apple M1`, `8589934592` bytes (8 GB) RAM, 8 cores, 59 GiB free disk.
  No Nix, Homebrew, Docker or VM tool installed.
- **Why it matters:** the pack assumes Ubuntu 24.04 on x86_64 (try9 was built in WSL2). An M1 Mac would need
  a Linux VM (arm64 = different binaries from try9, or x86 emulation = slow), with only 8 GB RAM to share,
  and the pack says ~30 GB of downloads. Where to run is an open decision (see "Open decisions").

### 3. Opened the git bundles (offline)
- **What:** `git bundle list-heads` on both bundles, then cloned them locally.
- **Result:**
  - `tt-sram-32x8.bundle` (submission repo): `main` = `b34ab81`, `origin/main` = `e85dd75`.
  - `tt_sram_tile_project.bundle` (tile project): `main` = `3576b6f`.
  - The submission repo's `build/` folder is the tile project (same LibreLane config, PDN Tcl, macro, tools).
    `diff -q build/config.yaml <pack>/repos/config.yaml` -> identical, so `build/config.yaml` **is** the try9 config.
- **Decision this supports:** the one-command build (D1) can live in the submission repo fork on a `flow/*`
  branch, next to `build/`, instead of a separate repo.

### 4. Local working copy
- `~/tt-sram-32x8`, branch `flow/reproducible-build`. The bundle remote is named `bundle`;
  there is no GitHub remote yet (the fork does not exist yet). Nothing pushed anywhere.

### 5. Decision: run the tools in the cloud (GitHub Actions + Codespaces)
- **Decided by the contributor**, 2026-11-16. Heavy runs go to GitHub Actions on the public fork (x86_64
  Ubuntu 24.04, free for public repos); Codespaces only for interactive debugging; the Mac only edits and pushes.
- **Why:** try9 was built on x86_64 Linux. Actions runs the same LibreLane Nix binaries on the same CPU type,
  so an exact reproduction is possible. The M1 Mac (8 GB RAM) would need an ARM VM (different binaries) or
  x86 emulation (slow).

### 6. Pinned versions, checked against the source (not assumed)
| What | Value | Where it was checked |
|---|---|---|
| LibreLane | 3.0.14 | `meta.librelane_version` in try9 `resolved.json` |
| sky130 PDK for LibreLane | `8afc8346a57fe1ab7934ba5a6056ea8b43078e71` | try9 `resolved.json` `PDK_ROOT`, and `librelane/pdk_hashes.yaml` at tag 3.0.14 (same hash, so LibreLane fetches it by default) |
| Nix binary cache | `nix-cache.fossi-foundation.org` + its public key | LibreLane 3.0.14 docs, `docs/source/installation/nix_installation/_common.md` |
| tt-support-tools (precheck) | `9d13ff3e3e6202090740110438c6a10c1d62ca0f` (commit date 2026-11-05) | pack `setup/TT_SUPPORT_TOOLS_VERSION.txt`; commit exists on GitHub |
| TT precheck PDK | `0536d02d875c8f67dd7cca3902ac457e62f20005` | pack `setup/PDK_VERSIONS.txt` = hard-coded in `TinyTapeout/tt-gds-action/precheck@ttsky26e` |

Network note: `raw.githubusercontent.com` is blocked on this network (curl error 35, connection reset), but
`github.com` and `api.github.com` work. Files were read through the GitHub API.

### 7. Inputs check: is `build/` exactly what try9 used?
- `cmp` of `build/{config.yaml, pdn/pdn_cfg.tcl, src/*.v, def/*.def, macro/*.lef, macro/*.v}` against the
  tile-project bundle: all identical.
- `shasum -a 256`: `build/macro/tt_sram_8x32_wpr1.gds` = `b5aa2ef0...81fb` = the pack's
  `tt_sram_8x32_wpr1_FIXED_implants_as_used_in_tile.gds`. (The raw OpenRAM GDS is different, `b9d8231f...45bc`,
  as expected: `fix_implants.py` changed it.)
- **Reference for the comparison:** try9 `final/metrics.json` (298 metrics) and the committed
  `gds/tt_um_rudresphotos_sram.gds` + `lef/tt_um_rudresphotos_sram.lef` (what the official TT precheck passed).
  The pack has no try9 `final/gds`, so the committed GDS is the reference. Copied the try9 metrics, resolved
  config, STA summary and precheck table into `flow/reference/try9/`.

### 8. Wrote the first part of D1 (tile rebuild only; OpenRAM regeneration comes after this reproduces)
- `flow/build_tile.sh [tag]`: LibreLane 3.0.14 -> checks PDK hash and outputs -> `test/run_gl.sh`
  (must print `0 errors -> PASS`) -> `tt_submission/`. Stops with `BUILD FAILED at step: ...`.
- `flow/compare_try9.py <run dir>`: (1) sign-off metrics must be 0, (2) all 298 try9 metrics must match
  exactly, (3) KLayout XOR per layer + pin labels vs committed GDS, (4) LEF diff. Exit 1 if any fails.
- `.github/workflows/reproduce_tile.yaml`: jobs `tile` -> (`compare`, `precheck`). Precheck is TT's own
  action, pinned to the try9 tt-support-tools commit. Runs on `flow/**` and `sta/**` branches only.
- No circuit file was changed (`build/`, `src/`, macro untouched). Added `test/tb_gl.vvp` to `.gitignore`.

### 9. Tested the compare script locally (KLayout Python 0.30.7 on the Mac; CI uses 0.30.13)
- **Test A:** try9 metrics + committed GDS/LEF compared against themselves:
  `298/298 metrics identical`, `39 layers compared: XOR empty, labels equal`, LEF `identical`, all 4 PASS, exit 0.
- **Test B:** planted `route__drc_errors=3`, `route__wirelength=9999` and a 1 um x 1 um box on layer 68/20 (met1):
  output `BAD route__drc_errors = 3`, `296/298 metrics identical`, `DIFF layer 68/20: 1 XOR polygons, area
  1.000000 um^2`, so 3 of 4 checks FAIL as intended.
- Not yet run: the real LibreLane build. That needs the fork on GitHub (next step).

### 10. Fork and CI set up (done by Claude with the contributor's saved GitHub login, as asked)
- Upstream check: `GET /repos/rudresphotos/tt-sram-32x8/commits/main` -> `b34ab81`, the same as the bundle's
  `main`, so no rebase was needed.
- Saved GitHub login has scopes `gist, read:org, repo, workflow` (from the `x-oauth-scopes` API header), so
  pushing workflow files works without a new token.
- Created fork `AaryanSharmaCodes/tt-sram-32x8` (API `POST .../forks`). Remotes in `~/tt-sram-32x8`:
  `origin` = fork, `upstream` = rudresphotos, `bundle` = pack bundle. Nothing was pushed to upstream.
- Pushed `flow/reproducible-build`. GitHub ran all 3 workflows on the fork. Disabled `gds` and `docs` **on the
  fork only** (API `PUT .../actions/workflows/<id>/disable`) and cancelled their 2 runs, so the fork never
  tries to deploy Pages. Upstream workflows are untouched.
- First `reproduce tile` run (`472aa6f`) failed at once: YAML error at line 93 (a `run:` value starting with
  `{` is read as a YAML mapping). Fixed with a `|` block, checked with `yaml.safe_load`, pushed as `952253d`.
- Run of `952253d`: https://github.com/AaryanSharmaCodes/tt-sram-32x8/actions/runs/43921286981 (result below).

### 11. CI run 1 (`952253d`, run 43921286981): LibreLane OK, my GL-test call failed
- Job `tile` 17:43:07 -> 17:47:33 UTC. LibreLane itself ran all 80 stages in 1 min 24 s (log 17:46:05 -> 17:47:29)
  and ended `Flow complete.` with its manufacturability report: `Antenna Passed`, `LVS Passed`, `DRC Passed`.
- PDK check: `PDK_ROOT = /home/runner/.ciel/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (= try9).
- Failure: `test/run_gl.sh: Permission denied` -> `BUILD FAILED at step: gate-level sim did not run`.
  Cause: `git ls-files -s test/run_gl.sh` shows mode `100644` (not executable). Fix in `flow/build_tile.sh`: call it
  with `bash`. Rudr's file is unchanged.
- Noted, not yet judged: Magic prints `Warning: cell "..._contact_25" placed on top of itself. Ignoring the extra one.`
  while reading the macro GDS at GDS stream-out. Need to check whether try9 had the same (the pack has no try9 flow log).
- Pushed `1d81265`; run 2: https://github.com/AaryanSharmaCodes/tt-sram-32x8/actions/runs/43922337307

### 12. CI run 2 (`1d81265`, run 43922337307): try9 REPRODUCED
All three jobs `success`. Job times (UTC): `tile` 17:49:11-17:53:30, `compare` 17:53:32-17:53:55,
`precheck` 17:53:32-17:55:54. LibreLane itself: 17:51:56 -> 17:53:20 (1 min 24 s).

| Check | Result (copied from the job logs / artifacts) |
|---|---|
| PDK used | `.../sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (= try9) |
| LibreLane manufacturability | `Antenna Passed`, `LVS Passed`, `DRC Passed`, `Flow complete.` |
| Sign-off counts | magic DRC 0, illegal overlap 0, LVS errors 0, route DRC 0, antenna nets 0 / pins 0, power grid 0, max slew/fanout/cap 0, flow errors 0 |
| All try9 metrics | `298/298 metrics identical` |
| GDS geometry | `39 layers compared: XOR empty, labels equal` (KLayout 0.30.13, vs committed `gds/`) |
| LEF | `identical` to committed `lef/` |
| Gate-level TT-pin test | `gate-level TT-pin test: 64 reads checked, 0 errors -> PASS` (Icarus Verilog 12.0 from Ubuntu apt) |
| TT precheck (tt-support-tools `9d13ff3`, log `HEAD is now at 9d13ff3`) | `Precheck passed ... 🎉`; `results.md` table has all 15 checks ✅ and is identical (`diff`) to try9's table |

**Is the GDS byte-identical?** No, and that is expected (D1 asks for XOR-equal, not byte-equal).
Both files are 1077488 bytes; SHA-256 rebuilt `95d22693...cdf6` vs committed `bac4dd08...3346`. A record-by-record
walk of both GDS streams (88107 records each) shows the only differing records are:
- 1 `BGNLIB` + 117 `BGNSTR` records = creation/modification dates written into the file, and
- 4362 `SNAME` + 110 `STRNAME` records = cell names. All 110 renamed cells differ only in a 3-character prefix
  (`ML_` in the rebuild vs `SC_` in the committed file, e.g. `ML_tt_sram_8x32_wpr1_pinv_9` vs
  `SC_tt_sram_8x32_wpr1_pinv_9`); the rest of every name is equal.
- 0 differing records of any other type (no geometry, layer, label or placement record differs).
The prefix is added to the macro's sub-cell names during Magic's GDS stream-out; it changes between runs.
TT's "Cell name check" passes with it.

The Magic messages `cell "..._contact_25" placed on top of itself. Ignoring the extra one.` appear 369 times in
the run-2 tile log. Since the XOR is empty and the metrics match, they do not change the result; they come from
reading OpenRAM's macro GDS.

**Conclusion:** the try9 tile build is reproduced from the committed inputs with one command
(`flow/build_tile.sh`, run by the `reproduce tile` workflow). This is the tile half of D1. Still to do for D1:
put OpenRAM macro generation + `fix_implants.py` in front of it, and add a `make tile` entry point.

### 13. Macro half of D1: how the tile's macro was made from OpenRAM's output (local checks on the Mac)
Why: D1 must start from the OpenRAM config, so I need the exact steps between OpenRAM's raw output and `build/macro/`.
- `build/macro/tt_sram_8x32_wpr1.{v,py,log}` and `.orig.lef` are byte-identical to the pack's raw OpenRAM output
  (`openram/macro_tt_sram_8x32_wpr1/`); `.orig.lef` = OpenRAM's LEF.
- GDS: `build/tools/fix_implants.py` on the raw GDS (sha256 `b9d8231f...45bc`). Run locally with the klayout Python
  package through `flow/klayout_run.py` (does what `klayout -zz -r SCRIPT -rd k=v` does). Its own report:
  `nsdm: added 99 fill polygons, 120.9610 um^2`, `psdm: added 32 fill polygons, 4.2348 um^2`,
  `npc: added 119 fill polygons, 10.5672 um^2`, two manual psdm bridges.
  `flow/gds_xor.py` result vs committed `build/macro/tt_sram_8x32_wpr1.gds`:
  `top cell tt_sram_8x32_wpr1: 29 layers compared: XOR empty, labels equal`.
  Negative test (raw, unfixed GDS vs committed): differences on exactly 93/44 nsdm (99 polygons), 94/20 psdm (33),
  95/20 npc (119) -> the check does catch real changes.
- LEF: the committed LEF = OpenRAM's LEF with two met4 OBS columns opened by `build/tools/open_obs_columns.py`.
  The column x-ranges are not written down anywhere; I read them from the diff and from `pdn/pdn_cfg.tcl`
  (stripes at macro-local 15.14..16.74 and 21.51..23.11, each widened by the 0.3 um met4 spacing):
  `cols="14.84,17.04;21.21,23.41"`. Output: `met4 OBS rects: 33 -> 23` and `diff` = identical to the committed LEF.

### 14. One command: `make tile` / `flow/build.sh`
- `flow/build_macro.sh`: OpenRAM at `2f7b3866` (shallow fetch) + `flow/openram/openram_local_changes.diff`, Python venv
  from the team's pinned `requirements-venv.txt`, OpenRAM's own `make sky130-pdk` / `make sky130-install`, then
  `sram_compiler.py` on `flow/openram/tt_sram_8x32_wpr1.py`; fails unless OpenRAM's log says `DRC Errors ... 0` and
  `LVS matches`; then fix_implants + LEF columns; installs into `build/macro/`.
- `flow/build.sh` = build_macro -> build_tile (LibreLane, GL test, tt_submission/) -> `flow/precheck.sh` (local TT
  precheck, same steps and pins as TT's precheck action) -> optional `CHECK_TRY9=1` comparison.
  `Makefile`: `make tile`, `make macro`, `make check`.
- `flow/compare_try9.py` gained check 0 (macro GDS XOR + LEF/V bytes vs the committed `build/macro/`, read from git HEAD).
- Fixed my own bug in `build_tile.sh`: a comment had swallowed `|| fail ...` after the GL-test call.

### 15. CI run 3 (`d8d4801`, run 43935832866): macro job failed in 1.5 min
- Steps 1-3 OK (OpenRAM checkout + patch, venv, PDK + cell library in ~1 min). Tool versions printed by the job:
  `magic /nix/store/1zcyq032zc3mzhmgs2j3q2rmfrjj5v6b-magic-vlsi-8.3.629`,
  `netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318`, `ngspice ...-ngspice-45`. The magic and
  netgen store paths are the same hashes as in Rudr's OpenRAM log of the try9 macro -> same tool builds.
- Failure: `FileNotFoundError: ... /home/runner/OpenRAM/macros/macro/tt_sram_8x32_wpr1/`: OpenRAM makes only the last
  directory level; on a fresh checkout `macros/macro/` does not exist. Fix: `mkdir -p` first.

### 16. CI run 4 (`043634f`, run 43936974433): the whole D1 chain passes from the OpenRAM config
- `macro` job (19:13-19:17 UTC): OpenRAM log `DRC Errors tt_sram_8x32_wpr1 0`, `tt_sram_8x32_wpr1 LVS matches`,
  `SIZE 147.895 BY 180.99` (= try9 macro); fix_implants printed exactly the numbers of entry 13
  (`nsdm: added 99 ...`, `psdm: added 32 ...`, `npc: added 119 ...`); `met4 OBS rects: 33 -> 23`; `MACRO OK`.
- `tile` job: with that macro, LibreLane -> GL test -> tt_submission -> local precheck (`flow/precheck.sh`):
  `INFO: Precheck passed ... 🎉`, all 15 rows ✅, then `ALL STEPS OK (run tag ci)`.
- The job then failed in my STA plumbing test (below), so `compare` and TT's precheck action were skipped in this run.

### 17. D2 first attempts: OpenRAM's characterizer and this macro
- Characterization run 1 (`887d417`, run 43936876637, `sram_char.py`): all 3 corners failed after ~90 s with
  `Trying feasible period: 10.0ns ... 1280.0ns` then `Timed out, could not find a feasible period.`, i.e. every
  simulation was judged a failed read, independent of the period.
- OpenRAM's analytical .lib written by the macro build is **0 bytes**. The macro log (CI and Rudr's try9 log) says
  `ERROR: file simulation.py: line 613: Could not find bl net in timing paths.` twice, followed by
  `Skipping delay stimulus:` and `Skipping lib characterization:`. So the generator's characterizer has never
  worked for this config; the skip-characterization change only hides that error. So "revert the patch" alone
  cannot give a .lib.
- Cause found for the stand-alone characterizer: it builds the bit-probe names from patterns and hard-codes the
  storage nets `Q` / `Q_bar`; the sky130 bitcell in the macro netlist (`.subckt sky130_custom_cell`) calls them
  `Q` / `Qbar`. Characterizer-only patch `flow/openram/openram_memchar_storage_names.diff` reads the names from the
  config (`memchar_storage_names = ("Q", "Qbar")`). No circuit file is touched.
- Rudr's OpenRAM diff is now two files (`openram_nwell5a.diff`, `openram_skip_characterization.diff`); applied
  together they give the same OpenRAM tree as the original diff (`git diff | shasum` identical:
  `dbd40866b424d5c1529e10abdac0675e45d3fe53`).

## Open items
- Contributor: revoke and re-create the GitHub CLI token. It was printed once in Claude's tool output on
  2026-11-16 during a credential check (GitHub -> Settings -> Applications -> Authorized OAuth Apps ->
  GitHub CLI -> Revoke, then log in again).
