# 前端构建阶段
FROM node:20-alpine AS frontend

WORKDIR /app

# 复制 package.json 和 package-lock.json
COPY package*.json ./

# 安装依赖
RUN npm ci && \
    npm install -D autoprefixer postcss @tailwindcss/postcss

# 复制前端资源
COPY resources/ ./resources/
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY postcss.config.js ./

# 构建前端资源
RUN npm run build

# Composer 依赖安装阶段
FROM composer:2 AS composer

WORKDIR /app

# 复制 composer 文件
COPY composer*.json ./

# 安装依赖
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# 复制应用代码
COPY . .

# 生成优化后的自动加载文件
RUN composer dump-autoload --optimize

# PHP 应用构建阶段
FROM php:8.2-fpm-bullseye AS laravel

# 安装系统依赖和 PHP 扩展
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-install \
    pdo_mysql \
    zip \
    opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 从 composer 阶段复制依赖
COPY --from=composer /app/vendor ./vendor
COPY --from=composer /app/composer.json ./composer.json
COPY --from=composer /app/composer.lock ./composer.lock

# 复制应用代码
COPY . .

# 从前端构建阶段复制构建后的资源
COPY --from=frontend /app/public/build ./public/build

# 设置目录权限
RUN chown -R www-data:www-data /app \
    && chmod -R 755 /app/storage \
    && chmod -R 755 /app/bootstrap/cache

# 复制 entrypoint 脚本并赋予可执行权限
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 配置 PHP
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/php.ini /usr/local/etc/php/conf.d/php.ini

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["php-fpm"]

# Nginx 配置阶段
FROM nginx:1.25-alpine AS nginx

# 创建 /app/public 目录，防止 COPY 失败
RUN mkdir -p /app/public

# 复制 Nginx 配置
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# 从 Laravel 阶段复制 public 目录
COPY --from=laravel /app/public /app/public

# 设置工作目录
WORKDIR /app

# 暴露端口
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]