.PHONY: init list backup-all update-all infra-up infra-down infra-logs

init:
	./scripts/init.sh

list:
	./scripts/list-sites.sh

backup-all:
	./scripts/backup-all.sh

update-all:
	./scripts/update-sites.sh

infra-up:
	docker compose --project-directory infrastructure -f infrastructure/compose.yml up -d

infra-down:
	docker compose --project-directory infrastructure -f infrastructure/compose.yml down

infra-logs:
	docker compose --project-directory infrastructure -f infrastructure/compose.yml logs -f
