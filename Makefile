python := "$(shell { command -v python2.7 || command -v python; } 2>/dev/null)"

# Set the relative path to installed binaries under the project virtualenv.
# NOTE: Creating a virtualenv on Windows places binaries in the 'Scripts' directory.
bin_dir := $(shell $(python) -c 'import sys; bin = "Scripts" if sys.platform == "win32" else "bin"; print(bin)')
env_bin := env/$(bin_dir)
venv := "./vendor/virtualenv-1.9.1.py"

env:
	$(python)  $(venv)\
				--unzip-setuptools \
				--prompt="[gittip] " \
				--never-download \
				--distribute \
				./env/
	if [ ! -d tarballs ]; then \
	    rm -rf tarballs; \
	    mkdir tarballs; \
	    ./$(env_bin)/pip install --download=tarballs -r requirements.txt; \
	    ./$(env_bin)/pip install --download=tarballs -r requirements_tests.txt; \
	fi
	./$(env_bin)/pip install --no-index --no-deps tarballs/*
	./$(env_bin)/pip install -e ./

clean:
	rm -rf env *.egg *.egg-info
	find . -name \*.pyc -delete

distclean: clean
	rm -rf tarballs

local.env:
	echo "Creating a local.env file ..."
	echo
	cp default_local.env local.env

cloud-db: env local.env
	echo DATABASE_URL=`./$(env_bin)/python -c 'import requests; print requests.get("http://api.postgression.com/").text'` >> local.env

schema: env local.env
	./$(env_bin)/swaddle local.env ./recreate-schema.sh

data:
	./$(env_bin)/swaddle local.env ./$(env_bin)/fake_data fake_data

db: cloud-db schema data

run: env local.env
	./$(env_bin)/swaddle local.env ./$(env_bin)/aspen \
		--www_root=www/ \
		--project_root=. \
		--show_tracebacks=yes \
		--changes_reload=yes \
		--network_address=:8537

test-cloud-db: env tests/env
	echo DATABASE_URL=`./$(env_bin)/python -c 'import requests; print requests.get("http://api.postgression.com/").text'` >> tests/env

test-schema: env tests/env
	./$(env_bin)/swaddle tests/env ./recreate-schema.sh

test-db: test-cloud-db test-schema

test: env tests/env test-schema
	./$(env_bin)/swaddle tests/env ./$(env_bin)/py.test ./tests/

tests: test

jstest:
	./node_modules/.bin/karma start karma-unit.conf.js
	./$(env_bin)/python jstests/scripts/e2e_runner.py

tests/env:
	echo "Creating a tests/env file ..."
	echo
	cp default_tests.env tests/env
