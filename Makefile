.PHONY: bootstrap bootstrap-server bootstrap-client \
	server/run server/lint server/test server/check \
	client/run client/run-sandbox client/smoke-windows-pdf client/run-android client/lint client/test client/check client/check-windows \
	test lint check clean

DEV_SCRIPT = powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1

bootstrap:
	$(DEV_SCRIPT) -Task bootstrap

bootstrap-server:
	$(DEV_SCRIPT) -Task bootstrap-server

bootstrap-client:
	$(DEV_SCRIPT) -Task bootstrap-client

server/run:
	$(DEV_SCRIPT) -Task run-server

server/lint:
	$(DEV_SCRIPT) -Task lint-server

server/test:
	$(DEV_SCRIPT) -Task test-server

server/check:
	$(DEV_SCRIPT) -Task check-server

client/run:
	$(DEV_SCRIPT) -Task run-client

client/run-sandbox:
	$(DEV_SCRIPT) -Task run-client-sandbox

client/smoke-windows-pdf:
	$(DEV_SCRIPT) -Task smoke-client-windows-pdf

client/run-android:
	$(DEV_SCRIPT) -Task run-client-android

client/lint:
	$(DEV_SCRIPT) -Task lint-client

client/test:
	$(DEV_SCRIPT) -Task test-client

client/check:
	$(DEV_SCRIPT) -Task check-client

client/check-windows:
	$(DEV_SCRIPT) -Task check-client-windows

test: client/test server/test

lint: client/lint server/lint

check:
	$(DEV_SCRIPT) -Task check

clean:
	$(DEV_SCRIPT) -Task clean
