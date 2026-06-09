include .env

.PHONY: up
up:
	@docker compose -p link-shortener up -d --remove-orphans

.PHONY: down
down:
	@docker compose -p link-shortener down

.PHONY: build
build:
	@docker compose -p link-shortener build

.PHONY: build-bin
build-bin:
	zig build -Doptimize=ReleaseFast
