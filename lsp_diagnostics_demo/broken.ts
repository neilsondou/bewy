function greet(name: string): number {
  return "hello " + name;  // type mismatch: string returned as number
}

const count: number = "abc";  // type mismatch
console.log(nonExistentVar);  // undefined symbol
let items: string[] = [1, 2, 3];  // type mismatch: numbers in string array
