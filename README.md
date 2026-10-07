# Run a local LLM in macOS Recovery mode

**Idea:** when a big model runs close to the GPU memory ceiling, the margin
between what it needs and what the GPU has available decides whether it runs
clean or thrashes. The surprise from measuring this: the thing eating that
margin is not the OS — it is **your running apps**.

On my machine (64 GB M1 Max, macOS 27.0.1, wired limit at 59000 MB), probed
via Metal (`recommendedMaxWorkingSetSize`): normal macOS with a browser + IDE
running — **55.4 GB** available; the same normal macOS with apps closed —
**57.6 GB**; Recovery mode — the same **57.6 GB**. A quiet normal boot and
Recovery expose identical GPU memory: the macOS baseline itself wires almost
nothing, while a browser-with-tabs + Electron session held ~2.3 GB.
**Closing your apps is the memory win; Recovery is just a guaranteed-empty
machine** (plus root `sysctl` without sudo). Rule of thumb from the cliff I
measured: keep **≥ ~4.5 GB of headroom** between what the server "needs" and
what is "available", or performance collapses.

Verified with an MLX-based server ([SUSHI](https://github.com/beamivalice/sushi))
serving a 176B-parameter MoE quant —
[beamster/Qwen3.8-Flash-Next-Sushi-3bpw](https://huggingface.co/beamster/Qwen3.8-Flash-Next-Sushi-3bpw)
(~49 GB of weights). As far as I know, running LLM inference inside Recovery
had not been documented before.

## What to know before starting

- Recovery has **Metal** (GPU compute) but **no MetalKit** — llama.cpp builds
  with a Metal backend crash there on startup. Use an MLX-based server
  (mlx-serve / SUSHI) — those need only frameworks Recovery ships.
- In Recovery you are **root**; the desktop is minimal; your disk is **not
  mounted automatically** — you mount it yourself (below).
- Wi-Fi works but is joined manually from the menu bar.
- This is a "night server" mode, not production: no auto-restart, and the
  Terminal window must stay open while the server runs.

## How to boot into Recovery (beginner-friendly)

1. Shut the Mac down completely ( → Shut Down).
2. Press and **hold the power button** until "Loading startup options" appears.
3. Click **Options → Continue**, pick your user, enter the password if asked.
4. In the Recovery app open **Utilities → Terminal** from the menu bar.

You now have a root terminal in a minimal macOS.

## What to roughly type

**1. Mount your data disk** (to reach the model and the server you already
have installed):

```bash
diskutil list                       # find your data volume, e.g. disk3s5
diskutil apfs unlockVolume disk3s5  # asks for your disk password (FileVault)
```

The volume appears under `/Volumes/…`.

**2. Let the GPU use more RAM** — the whole point of the trick. Normally this
needs `sudo` after every boot; in Recovery you are already root:

```bash
sysctl iogpu.wired_limit_mb=59000   # for 64 GB Macs
```

**3. Start the server from the mounted volume.** Example with SUSHI:

```bash
/opt/homebrew/Cellar/sushi/*/libexec/sushi serve \
  --model "/Volumes/YourVolume/Users/you/models/Qwen3.8-Flash-Next-Sushi-3bpw" \
  --host 0.0.0.0 --port 8080 --ctx-size 98304 --kv-quant 8
```

Two gotchas:

- Run the **real binary**, not a symlink from `/opt/homebrew/bin`, and prefer
  binaries with `@executable_path`-relative libraries — absolute
  `/opt/homebrew/...` paths do not resolve in Recovery.
- 2-second sanity check before loading any model:

  ```bash
  /path/to/sushi --version    # should print a "[mem] MLX ..." line
  ```

  If that prints, Metal works in your Recovery and inference will too.

**4. Join Wi-Fi** (menu bar, top right), then from any other machine:

```bash
ipconfig getifaddr en0               # on the Recovery Mac: its LAN IP
curl http://<mac-ip>:8080/v1/models  # from another machine
```

Point any OpenAI-compatible client (LM Studio, Kilo Code, pi, curl) at
`http://<mac-ip>:8080/v1` and use the model. Reboot normally when done —
nothing on your disk changed.

## Credits

- [SUSHI](https://github.com/beamivalice/sushi) — the engine used (fork of
  [mlx-serve](https://github.com/ddalcu/mlx-serve))
- [beamster/Qwen3.8-Flash-Next-Sushi-3bpw](https://huggingface.co/beamster/Qwen3.8-Flash-Next-Sushi-3bpw) — the example model pack

## License

MIT — see [LICENSE](LICENSE).
