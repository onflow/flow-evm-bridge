package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"
	"strconv"

	. "github.com/bjartek/overflow"
)

func main() {
	o := Overflow()

	totalStored := 1000000
	batchSize := 100
	strings := make([]string, batchSize)
	for j := range strings {
		strings[j] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
	}
	// Create a go map of int to int called comp
	computation := make(map[int]int)

	for i := 0; i < totalStored; i += batchSize {
		if i%1000 == 0 {
			fmt.Printf("i: %d\n", i)
		}
		result := o.Tx(
			"bench/store",
			WithSignerServiceAccount(),
			WithArg("strings", strings),
			WithoutLog(),
			WithMaxGas(9999),
		)
		computation[i] = result.ComputationUsed

		if result.Err != nil {
			fmt.Printf("Insertion failed at i == %d - Exiting...\n", i)
			OutputFile(computation, "computation.csv")
			os.Exit(1)
		}
	}

	OutputFile(computation, "plot/computation.csv")
}

func OutputFile(computation map[int]int, filename string) {
	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	var keys []int
	for key := range computation {
		keys = append(keys, key)
	}
	sort.Ints(keys)

	for _, key := range keys {
		value := computation[key]
		err := writer.Write([]string{strconv.Itoa(key), strconv.Itoa(value)})
		if err != nil {
			panic(err)
		}
	}
}
