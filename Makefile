.PHONY: up down logs backend-test frontend-test lint

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

backend-test:
	cd backend && PYTHONPATH=. .venv/bin/python -m pytest tests/ -q

backend-analyze:
	cd backend && .venv/bin/python -m compileall -q app

frontend-test:
	cd frontend && flutter test

frontend-analyze:
	cd frontend && flutter analyze

lint: backend-analyze frontend-analyze
