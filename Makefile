HERE = $(shell pwd)
BIN = $(HERE)/venv/bin
PYTHON = python3.4
VENV_PYTHON = $(BIN)/$(PYTHON)
PIP = $(BIN)/pip
VTENV_OPTS = --python $(PYTHON)

INSTALL = $(BIN)/pip install

LOOP_SERVER_URL = https://loop.stage.mozaws.net:443
FXA_EXISTING_EMAIL =


.PHONY: all test build

all: build test

$(VENV_PYTHON):
	virtualenv $(VTENV_OPTS) venv
	$(PIP) install -r requirements.txt
build: $(VENV_PYTHON)

loadtest.env:
	$(BIN)/fxa-client -c --browserid --prefix loop-server --audience https://loop.stage.mozaws.net --out loadtest.env

refresh:
	@rm -f loadtest.env

setup_random: refresh loadtest.env

setup_existing:
	$(BIN)/fxa-client --browserid --auth "$(FXA_EXISTING_EMAIL)" --account-server https://api.accounts.firefox.com/v1 --audience https://loop.stage.mozaws.net --out loadtest.env


test: build loadtest.env
	bash -c "source loadtest.env && LOOP_SERVER_URL=$(LOOP_SERVER_URL) $(BIN)/ailoads -v -d 30"
	$(BIN)/flake8 loadtest.py

test-heavy: build loadtest.env
	bash -c "source loadtest.env && LOOP_SERVER_URL=$(LOOP_SERVER_URL) $(BIN)/ailoads -v -d 300 -u 10"

clean: refresh
	rm -fr venv/ __pycache__/

docker-build:
	docker build -t loop/loadtest .

docker-run: loadtest.env
	bash -c "source loadtest.env; docker run -e LOOP_DURATION=600 -e LOOP_NB_USERS=50 -e FXA_BROWSERID_ASSERTION=\$${FXA_BROWSERID_ASSERTION} loop/loadtest"

configure: build loadtest.env
	@bash loop.tpl

docker-export:
	docker save "loop/loadtest:latest" | bzip2> loop-latest.tar.bz2
