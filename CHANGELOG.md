# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- **Windows suite scripts (`scripts/start_suite.ps1`, `scripts/stop_suite.ps1`)**  
  - UTF-8 BOM and parser-safe strings so Windows PowerShell loads the scripts correctly.  
  - `stop_suite.ps1`: stopped using `$pid` as a variable (conflicts with the read-only `$PID` automatic variable); stopped `llama-server` via `Qwen3.6/.qwen_pid`; process-tree kill via `taskkill /F /T`; port cleanup with `netstat` fallback; Docker `stop` / `down` ordering; no conflicting `Start-Process -WindowStyle` + `-NoNewWindow`.  
  - `start_suite.ps1`: health-check progress; Docker Compose exit handling; `mix` preflight for Phoenix; clearer error log tails; `UID`/`GID` defaults for Compose on Windows; Qwen/Phoenix helper `Start-Process` hardening; **`Invoke-WebRequest` no longer leaves the “Reading web response” progress UI** (`$ProgressPreference` scoped in `Test-Http`).  
  - **`docker compose up`** run through **`cmd /c` … `2>&1`** so PowerShell 7 does not treat Compose stderr as a terminating error under `$ErrorActionPreference = Stop`.  
  - On success, **opens the Phoenix workbench in the default browser** (use **`-NoBrowser`** to skip, e.g. CI).

- **Qwen local server (`Qwen3.6/scripts/start_qwen.ps1`)**  
  - Port checks use **`.NET IPGlobalProperties`** instead of `Get-NetTCPConnection` where NetTCPIP is unavailable or flaky.

- **LibreChat Docker (tracked overlay `Qwen3.6/compose.librechat-workshop.yml`)**  
  - `start_suite` / `stop_suite` (PowerShell and bash) merge **`docker-compose.yml`** with this file so workshop settings are versioned while **`Qwen3.6/librechat/`** stays gitignored for local DB, `.env`, and uploads.  
  - **MongoDB**: **`999:999`** (official `mongo:8` user) for `./data-node` on Docker Desktop.  
  - **Meilisearch**: **`MEILI_HTTP_ADDR`**, **`0:0`** on bind mounts (fixes permission denied / crash loops on Windows).  
  - **LibreChat API**: **`0:0`** so **`./logs`** / **`./uploads`** bind mounts are writable (`EACCES` on `error-*.log`).  
  - **Voice service**: build **`context: ../ClaudeSpeak`** relative to the tracked compose file.

- **Upstream LibreChat base (`Qwen3.6/librechat/docker-compose.yml`, when present locally)**  
  - **Meilisearch**: removed erroneous **`MEILI_HOST`** from the Meilisearch service (that URL belongs on the API only).

### Changed

- **`.gitignore`**: extend media ignore patterns for shorts tooling (unchanged policy: whole **`Qwen3.6/librechat/`** directory remains ignored except what upstream nested `.gitignore` already excludes).
