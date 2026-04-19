# syntax=docker/dockerfile:1
#
# Multi-stage production build for ORCWorkbench.
#
# Build context: the repository root (WorldModels/). This is required
# because apps/agent_plane/mix.exs has a `path:` dep on the jido
# submodule that lives one directory above the umbrella:
#
#   {:jido, path: "../../../jido"}  <- from apps/agent_plane/
#
# That resolves to WorldModels/jido/ in the repo; inside the builder
# image it resolves to /jido.
#
# Usage:
#   docker compose up --build         (recommended — see docker-compose.yml)
#   docker build -t orcworkbench .    (raw)

# NB. hexpm/elixir tags for 1.18.4 + OTP 27.3 are Alpine-only. The
# release bundles its own ERTS, so the runtime image only needs
# libstdc++ and openssl — Alpine is plenty.
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4
ARG ALPINE_VERSION=3.21.7

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# =============================================================================
# Stage 1: builder — compile umbrella + build release
# =============================================================================
FROM ${BUILDER_IMAGE} AS builder

RUN apk add --no-cache build-base git

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Jido path dep (../../../jido from apps/agent_plane/) → /jido at image root.
COPY jido /jido

WORKDIR /build

# Deps first (cache-friendly).
COPY active_inference/mix.exs active_inference/mix.lock ./
COPY active_inference/config ./config
COPY active_inference/apps ./apps
# Standalone learning-lab HTML files — surfaced to Phoenix via
# `mix workbench_web.sync_labs` below so they are served under /learninglabs.
COPY learninglabs /learninglabs
# Prune any local build/deps that may have been copied in (belt + braces
# in case .dockerignore is bypassed).
RUN rm -rf _build deps

RUN mix deps.get --only prod
RUN mix deps.compile

# Copy labs into workbench_web's priv/static BEFORE compile so the
# release bundler includes them.
RUN mix workbench_web.sync_labs

RUN mix compile

RUN mix release orcworkbench

# =============================================================================
# Stage 2: runner — minimal image carrying the release tarball
# =============================================================================
FROM ${RUNNER_IMAGE} AS runner

RUN apk add --no-cache \
      libstdc++ \
      openssl \
      ncurses-libs \
      ca-certificates \
      tini

WORKDIR /app

# Non-root user. Mnesia needs to write to /data so the dir is created
# and chowned here; the docker-compose volume mount inherits this.
RUN addgroup -S -g 1000 app \
 && adduser  -S -u 1000 -G app -h /app -s /sbin/nologin app \
 && mkdir -p /data/mnesia \
 && chown -R app:app /app /data

USER app

COPY --from=builder --chown=app:app /build/_build/prod/rel/orcworkbench /app

ENV MNESIA_DIR=/data/mnesia \
    PORT=4000 \
    PHX_HOST=localhost \
    HOME=/app \
    # Stable node name across container restarts. Mnesia disc_copies
    # are keyed by node(); if the name changes on restart, the existing
    # tables in the /data volume become unreadable (wait_for_tables
    # timeout). `none` means no distribution — node() returns
    # :nonode@nohost, which is stable.
    RELEASE_DISTRIBUTION=none

VOLUME ["/data"]
EXPOSE 4000

# tini handles PID 1 + signal forwarding cleanly for the BEAM.
ENTRYPOINT ["/sbin/tini", "--", "/app/bin/orcworkbench"]
CMD ["start"]
