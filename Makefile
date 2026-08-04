.PHONY: backend-test backend-run backend-analyze backend-script frontend-run frontend-test frontend-analyze lint

PY ?= .venv/bin/python

backend-analyze:
	cd backend && PYTHONPATH=app $(PY) -m compileall -q app

backend-test:
	cd backend && PYTHONPATH=. $(PY) -m pytest tests -q

backend-run:
	cd backend && .venv/bin/uvicorn app.main:app --reload

backend-script:
	scripts/run_script.sh backend/$(SCRIPT)

frontend-run:
	scripts/run_script.sh frontend/run

frontend-analyze:
	scripts/run_script.sh frontend/analyze

frontend-test:
	scripts/run_script.sh frontend/test

lint: backend-analyze frontend-analyze