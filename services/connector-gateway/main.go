package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8082"
    }

    mux := http.NewServeMux()
    mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte("ok"))
    })
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        _, _ = w.Write([]byte("connector-gateway stub\n"))
    })

    addr := fmt.Sprintf(":%s", port)
    log.Printf("connector-gateway listening on %s", addr)
    log.Fatal(http.ListenAndServe(addr, mux))
}
