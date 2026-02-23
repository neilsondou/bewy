package main

import "fmt"

func main() {
    var x int = "hello"  // type mismatch
    fmt.Println(undeclaredVar)  // undefined variable
    y := 42
    // unused variable y (Go treats this as error)

    if true {
        fmt.Println("test"
    // missing closing paren
}
