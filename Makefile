.PHONY: backend-test backend-run backend-analyze backend-script frontend-run frontend-build-apk frontend-analyze frontend-test lint

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

frontend-build-apk:
	scripts/run_script.sh frontend/build_apk

frontend-analyze:
	scripts/run_script.sh frontend/analyze

frontend-test:
	scripts/run_script.sh frontend/test

lint: backend-analyze frontend-analyze