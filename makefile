# ===============================
# 🐳 Docker Compose Makefile
# ===============================

# Compose base
DC=docker compose

# -------------------------------
# 🔨 Build all images
# -------------------------------
build:
	$(DC) build

# -------------------------------
# ✅ Run tests
# -------------------------------
test:
	$(DC) run --rm etl_test

# -------------------------------
# 🧹 Remove containers & volumes
# -------------------------------
clean:
	$(DC) down -v --remove-orphans

# -------------------------------
# 🆙 Bring everything up (dev)
# -------------------------------
up:
	$(DC) up

# -------------------------------
# 🛑 Stop all containers
# -------------------------------
stop:
	$(DC) down

# ----------------------------------------
# 🔥 Remove ALL stopped containers + volumes
# ----------------------------------------
clean-volumes:
	@echo "Stopping containers and removing volumes..."
	docker compose down -v --remove-orphans
	@echo "Pruning dangling volumes..."
	docker volume prune -f
