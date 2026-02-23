SELEC * FROM users;  -- typo: SELEC instead of SELECT

INSERT INTO users (name, age VALUES ('Alice', 30);  -- missing closing paren

CREATE TABLE orders (
    id INT PRIMARY KEY,
    user_id INT,
    total DECIMAL(10, 2
);  -- missing closing paren in DECIMAL

UPDATE users SET name = 'Bob' WERE id = 1;  -- typo: WERE instead of WHERE
