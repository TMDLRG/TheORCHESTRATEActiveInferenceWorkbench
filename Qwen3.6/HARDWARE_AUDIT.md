# HARDWARE_AUDIT

Captured 2026-04-18 on THINKER. All read-only inspection; nothing was modified during collection.

## Machine

| Attribute | Value |
|---|---|
| Hostname | THINKER |
| Make / model | Lenovo 30DFS0UY00 (ThinkStation-class workstation) |
| OS | Windows 11 Pro, Build 26200 |
| BIOS | LENOVO M2WKT5BA (2023-10-18) |
| Install date | 2025-02-01 |
| Timezone | UTC-06:00 (Central) |
| Hypervisor | Virtualization-based security running (VBS active) |

## CPU

| Attribute | Value |
|---|---|
| Model | Intel Core i7-10700T |
| Microarch | Comet Lake (SM 7.5-era, pre-AVX-512) |
| Cores / threads | 8 physical / 16 logical |
| Base clock | 1.99 GHz (2.00 GHz advertised, T-series low-TDP part) |
| AVX2 | Yes (llama.cpp loaded `ggml-cpu-haswell.dll` confirming AVX2 path) |
| AVX-512 | No (Comet Lake disabled it) |

## Memory

| Attribute | Value |
|---|---|
| Installed RAM | 65.24 GB (≈64 GB DDR4) |
| Free at audit time | ~32 GB (LM Studio + Chrome + misc. holding the rest) |
| Virtual memory max | 83.67 GB (pagefile + RAM) |

## GPUs

| Index | Model | VRAM | Driver | CUDA runtime | Compute cap | Notes |
|---|---|---|---|---|---|---|
| 0 | NVIDIA T1000 | 4095 MiB | 581.42 | 13.0 (driver-bundled) | 7.5 (Turing) | In-use by LM Studio (101 MB); no native FP8 tensor cores |
| 1 | Intel UHD Graphics 630 | 1073 MiB | 31.0.101.2135 | n/a | n/a | iGPU, not usable for CUDA |

**CUDA toolkit**: NOT installed (no `nvcc`, no `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\`). Only driver-bundled runtime is present.

## Storage

| Mount | Total | Used | Free |
|---|---|---|---|
| C: | 1.86 TB | 1.40 TB | ≈ 433–470 GB (fluctuated during model download) |
| D: | 116 GB | 59 GB | 57 GB |

## Networking / ports

- Ethernet: Intel I219-LM, connected, DHCP 10.0.0.39, DNS 10.0.0.1
- Wi-Fi 6 AX201, Bluetooth: disconnected
- Port 8000: in use by LM Studio
- Ports 3080 / 3090 / 8090 / 8091 / 8092: free at audit time

## Toolchain

| Tool | Version |
|---|---|
| Git | 2.51.1.windows.1 |
| Node | v25.0.0 |
| npm | 11.6.2 |
| CMake | not installed |
| Python | 3.12.10 (system, at `C:\Users\mpolz\AppData\Local\Programs\Python\Python312\`) |
| pip | 25.0.1 |
| uv (astral) | 0.9.7 |
| conda | not installed |
| curl | 8.16.0 |
| Docker Desktop | 28.5.1 (build e180ab8) |
| docker compose | v2.40.3-desktop.1 |
| WSL2 | active, distros: Ubuntu, docker-desktop, podman-machine-default (all running) |

## HuggingFace

- No `HF_TOKEN` or `HUGGING_FACE_HUB_TOKEN` set in environment at audit.
- Local HF cache at `~/.cache/huggingface/hub/` (88 MB pre-audit; grew to ~35 GB during this deployment).

## Audit-time environment

Collected via `systeminfo.exe`, `wmic` + PowerShell `Get-CimInstance`, `nvidia-smi.exe`, `powershell Get-NetTCPConnection`, `docker --version / info`, `wsl --list --verbose`, `git / node / npm / python / uv --version`, `curl --version`, and disk `Get-PSDrive` snapshots. No command altered state.
