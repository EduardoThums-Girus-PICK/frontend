package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	fmt.Println("Request failed:")

	resp, err := http.Get("http://localhost:8080")
	if err != nil {
		fmt.Println("Request failed:", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Println("Unexpected status code:", resp.StatusCode)
		os.Exit(1)
	}

	os.Exit(0)
}
