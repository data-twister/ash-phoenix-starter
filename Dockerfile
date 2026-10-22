# ==========================================
# STAGE 1: Build the Release artifact
# ==========================================
FROM elixir:1.19-slim AS builder

# Set production environment variables
ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Install system dependencies needed for compiling Elixir deps and native C code
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libzstd-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install hex and rebar package managers
RUN mix local.hex --force && \
    mix local.rebar --force

# Set workspace
WORKDIR /app

# Copy dependency configuration files first to optimize layer caching
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs ./config/

# Fetch only production dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy asset paths and web files for compilation
COPY priv priv
COPY lib lib
COPY assets assets

# Setup, build, and compress web assets (phoenix_bakery hooks into phx.digest)
RUN mix assets.setup
RUN mix assets.deploy

# Compile the final Elixir application
RUN mix compile

# Copy runtime configuration last (as variables change frequently at boot)
COPY config/runtime.exs ./config/

# Build the release binary
RUN mix release --overwrite

# ==========================================
# STAGE 2: Lightweight Runtime Environment
# ==========================================
FROM debian:bookworm-slim AS runner

# Set production environment variables
ENV LANG=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true

# Install runtime OS libraries (libzstd1 is required here so the compiled bakery assets can be read)
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libzstd1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set runtime working directory
WORKDIR /app

# Ensure ownership is given to non-root user
RUN chown nobody /app

# Copy the built release artifact from the builder stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/AshPhoenixStarter ./

# Copy the migration execution script explicitly
COPY --chown=nobody:root start.sh ./start.sh

# Shift to non-privileged runtime user for container safety
USER nobody

# Expose the default Phoenix web port for Render (10000)
EXPOSE 10000

# Execute the start script to run migrations and trigger app boot sequentialy
CMD ["/app/start.sh"]
