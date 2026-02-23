<?php

declare(strict_types=1);

namespace App\Services;

class QueryBuilder
{
    private string $table;
    private array $conditions = [];
    private array $orderBy = [];
    private ?int $limit = null;
    private array $columns = ['*'];

    public function __construct(string $table)
    {
        $this->table = $table;
    }

    public static function table(string $name): self
    {
        return new self($name);
    }

    public function select(string ...$columns): self
    {
        $this->columns = $columns;
        return $this;
    }

    public function where(string $column, string $operator, mixed $value): self
    {
        $this->conditions[] = compact('column', 'operator', 'value');
        return $this;
    }

    public function orderBy(string $column, string $direction = 'ASC'): self
    {
        $this->orderBy[] = "$column $direction";
        return $this;
    }

    public function limit(int $count): self
    {
        $this->limit = $count;
        return $this;
    }

    public function toSQL(): string
    {
        $cols = implode(', ', $this->columns);
        $sql = "SELECT $cols FROM {$this->table}";

        if (!empty($this->conditions)) {
            $clauses = array_map(function (array $cond): string {
                $val = is_string($cond['value']) ? "'{$cond['value']}'" : $cond['value'];
                return "{$cond['column']} {$cond['operator']} $val";
            }, $this->conditions);
            $sql .= ' WHERE ' . implode(' AND ', $clauses);
        }

        if (!empty($this->orderBy)) {
            $sql .= ' ORDER BY ' . implode(', ', $this->orderBy);
        }

        if ($this->limit !== null) {
            $sql .= " LIMIT {$this->limit}";
        }

        return $sql;
    }
}

// Usage
$query = QueryBuilder::table('users')
    ->select('id', 'name', 'email')
    ->where('age', '>', 18)
    ->where('status', '=', 'active')
    ->orderBy('name')
    ->limit(10)
    ->toSQL();

echo $query . PHP_EOL;
