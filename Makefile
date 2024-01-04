.PHONY: setup
setup:
	go mod tidy
	pip install -r plot/requirements.txt

.PHONY: bench
bench:
	go run main.go

.PHONY: plot
plot:
	python plot/plot_computation.py plot/computation.csv
