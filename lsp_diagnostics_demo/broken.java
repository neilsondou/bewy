public class broken {
    public static void main(String[] args) {
        int x = "hello";  // type mismatch
        System.out.println(unknownVar);  // undefined symbol
        String name = 42  // missing semicolon

        if (true {  // missing closing paren
            System.out.println("test");
        }
    }
}
