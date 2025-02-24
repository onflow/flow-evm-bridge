.PHONY: test
test: 
	sh local/run_cadence_tests.sh
	go test

.PHONY: ci
ci: check-tidy test

.PHONY: check-tidy
check-tidy: 
	go mod tidy
	git diff --exit-code