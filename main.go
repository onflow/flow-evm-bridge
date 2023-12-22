package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"strconv"

	. "github.com/bjartek/overflow"
)

func main() {
	o := Overflow()

	totalStored := 10000000
	batchSize := 10000
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
		if i != 0 && i%10000 == 0 {
			fmt.Println("Querying...")

			var value string
			result := o.Script("bench/query").MarshalAs(value)

			fmt.Println("Result: ", result)
		}
		result := o.Tx(
			"bench/store",
			WithSignerServiceAccount(),
			WithArg("strings", strings),
			WithoutLog(),
			WithMaxGas(99999),
		)
		computation[i] = result.ComputationUsed

		if result.Err != nil && batchSize == 1 {
			// if result.Err != nil {
			fmt.Printf("Insertion failed at i == %d - Exiting...\n", i)
			OutputFile(computation, "computation.csv")
			os.Exit(1)
		}

		if result.Err != nil {
			batchSize = batchSize / 2
			fmt.Printf("Failed batch size of %d at i == %d - halving batch size\n", batchSize, i)
		}
	}

	OutputFile(computation, "computation.csv")
}

func OutputFile(computation map[int]int, filename string) {
	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	// Create a CSV writer
	writer := csv.NewWriter(file)
	defer writer.Flush()

	// Iterate over the map and write to CSV
	for key, value := range computation {
		err := writer.Write([]string{strconv.Itoa(key), strconv.Itoa(value)})
		if err != nil {
			panic(err)
		}
	}
}
