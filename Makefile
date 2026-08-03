.PHONY: backend-test backend-run backend-analyze frontend-run frontend-test frontend-analyze lint

PY ?= .venv/bin/python

backend-analyze:
	cd backend && PYTHONPATH=app $(PY) -m compileall -q app

backend-test:
	cd backend && PYTHONPATH=. $(PY) -m pytest tests -q

backend-run:
	cd backend && .venv/bin/uvicorn app.main:app --reload

frontend-run:
	cd frontend && flutter run

frontend-analyze:
	cd frontend && flutter analyze

frontend-test:
	cd frontend && flutter test

lint: backend-analyze frontend-analyze