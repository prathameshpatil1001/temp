PROTO_DIR := proto
CORE_API_DIR := services/core-api
MODULE := github.com/chirag3003/lms-monorepo/services/core-api
MIGRATIONS_DIR := $(CORE_API_DIR)/internal/repository/migrations
MIGRATE ?= migrate
POSTGRES_DSN ?= postgres://lms:lms@localhost:15432/lms?sslmode=disable
DOCKER_POSTGRES_DSN ?= postgres://lms:lms@postgres:5432/lms?sslmode=disable
export PATH := $(PATH):$(shell go env GOPATH)/bin

.PHONY: proto sqlc docker-up docker-down migrate-up migrate-down migrate-force migrate-version migrate-create migrate-up-docker migrate-force-docker migrate-version-docker

proto:
	protoc \
		-I $(PROTO_DIR) \
		--go_out=$(CORE_API_DIR) \
		--go_opt=module=$(MODULE) \
		--go-grpc_out=$(CORE_API_DIR) \
		--go-grpc_opt=module=$(MODULE) \
		$(PROTO_DIR)/admin/v1/admin.proto \
		$(PROTO_DIR)/auth/v1/auth.proto \
		$(PROTO_DIR)/chat/v1/chat.proto \
		$(PROTO_DIR)/dst/v1/dst.proto \
		$(PROTO_DIR)/kyc/v1/kyc.proto \
		$(PROTO_DIR)/media/v1/media.proto \
		$(PROTO_DIR)/onboarding/v1/onboarding.proto \
		$(PROTO_DIR)/loan/v1/loan.proto \
		$(PROTO_DIR)/query/v1/query.proto \
		$(PROTO_DIR)/branch/v1/branch.proto

sqlc:
	cd $(CORE_API_DIR) && sqlc generate

docker-up:
	docker compose up -d

docker-down:
	docker compose down

migrate-up:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(POSTGRES_DSN)" up

migrate-down:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(POSTGRES_DSN)" down 1

migrate-force:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make migrate-force VERSION=<n>"; exit 1; fi
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(POSTGRES_DSN)" force $(VERSION)

migrate-version:
	$(MIGRATE) -path $(MIGRATIONS_DIR) -database "$(POSTGRES_DSN)" version

migrate-create:
	@if [ -z "$(NAME)" ]; then echo "Usage: make migrate-create NAME=<snake_case_name>"; exit 1; fi
	$(MIGRATE) create -ext sql -dir $(MIGRATIONS_DIR) -seq $(NAME)

migrate-up-docker:
	docker compose run --rm migrate -path /migrations -database "$(DOCKER_POSTGRES_DSN)" up

migrate-force-docker:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make migrate-force-docker VERSION=<n>"; exit 1; fi
	docker compose run --rm migrate -path /migrations -database "$(DOCKER_POSTGRES_DSN)" force $(VERSION)

migrate-version-docker:
	docker compose run --rm migrate -path /migrations -database "$(DOCKER_POSTGRES_DSN)" version
