#!/usr/bin/env bash
set -o errexit

# Run Ecto & Ash migrations using the Release module we built
/app/bin/AshPhoenixStarter eval "AshPhoenixStarter.Release.migrate"

# Boot the web application endpoint
exec /app/bin/AshPhoenixStarter start
