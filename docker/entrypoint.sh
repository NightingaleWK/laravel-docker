#!/bin/sh
set -e

# 1. 复制 .env
if [ ! -f .env ]; then
    echo "[Entrypoint] .env not found, copying from .env.example..."
    cp .env.example .env
fi

# 2. 生成 APP_KEY
if ! grep -q '^APP_KEY=\w' .env; then
    echo "[Entrypoint] Generating APP_KEY..."
    php artisan key:generate --force
fi

# 3. storage:link
if [ ! -L public/storage ]; then
    echo "[Entrypoint] Creating storage symlink..."
    php artisan storage:link || true
fi

# 4. 设置默认数据库为 sqlite
if ! grep -q '^DB_CONNECTION=' .env; then
    echo "[Entrypoint] Setting DB_CONNECTION=sqlite..."
    echo "DB_CONNECTION=sqlite" >> .env
    echo "DB_DATABASE=/app/database/database.sqlite" >> .env
    touch /app/database/database.sqlite
fi

exec "$@" 