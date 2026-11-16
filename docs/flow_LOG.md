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

## Open items
- Contributor: create the fork on GitHub, enable Actions, disable the fork's `gds`/`docs` workflows, and set up
  push access (a token with `workflow` scope is needed to push files under `.github/workflows/`).
