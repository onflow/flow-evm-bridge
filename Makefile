.PHONY: test
test:
	make cdc-test
	make go-test

.PHONY: check-tidy
check-tidy:
	go mod tidy
	git diff --exit-code

.PHONY: ci
ci: check-tidy test

.PHONY: cdc-test
cdc-test:
	flow test --cover --covercode="contracts" --coverprofile="coverage.lcov" cadence/tests/*_tests.cdc

.PHONY: go-test
go-test:
	go test