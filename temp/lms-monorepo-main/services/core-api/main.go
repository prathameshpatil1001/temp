package main

import (
	"log"

	"github.com/chirag3003/lms-monorepo/services/core-api/cmd/server"
)

func main() {
	if err := server.Run(); err != nil {
		log.Fatal(err)
	}
}
