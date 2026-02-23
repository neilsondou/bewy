#!/bin/bash

function greet() {
    echo "Hello, $1"
# missing closing brace

if [ -f "test.txt" ]; then
    echo "file exists"
# missing fi

for i in 1 2 3; do
    echo $i
# missing done

NAME=echo "bad assignment"  # incorrect syntax
