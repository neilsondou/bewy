<?php

function add($a, $b) {
    return $a + $b
}  // missing semicolon on return

$name = "world"
echo "Hello, " . $undefinedVar;  // undefined variable

class MyClass {
    public function getValue( {  // missing closing paren
        return $this->value;
    }
}
