use std::collections::HashMap;
use std::fmt;

#[derive(Debug, Clone)]
struct Matrix {
    rows: usize,
    cols: usize,
    data: Vec<Vec<f64>>,
}

impl Matrix {
    fn new(rows: usize, cols: usize) -> Self {
        Matrix {
            rows,
            cols,
            data: vec![vec![0.0; cols]; rows],
        }
    }

    fn from_vec(data: Vec<Vec<f64>>) -> Result<Self, &'static str> {
        if data.is_empty() {
            return Err("Empty matrix");
        }
        let cols = data[0].len();
        if data.iter().any(|row| row.len() != cols) {
            return Err("Inconsistent row lengths");
        }
        Ok(Matrix {
            rows: data.len(),
            cols,
            data,
        })
    }

    fn multiply(&self, other: &Matrix) -> Result<Matrix, &'static str> {
        if self.cols != other.rows {
            return Err("Dimension mismatch");
        }
        let mut result = Matrix::new(self.rows, other.cols);
        for i in 0..self.rows {
            for j in 0..other.cols {
                for k in 0..self.cols {
                    result.data[i][j] += self.data[i][k] * other.data[k][j];
                }
            }
        }
        Ok(result)
    }

    fn transpose(&self) -> Matrix {
        let mut result = Matrix::new(self.cols, self.rows);
        for i in 0..self.rows {
            for j in 0..self.cols {
                result.data[j][i] = self.data[i][j];
            }
        }
        result
    }
}

impl fmt::Display for Matrix {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        for row in &self.data {
            let s: Vec<String> = row.iter().map(|v| format!("{:8.2}", v)).collect();
            writeln!(f, "[{}]", s.join(", "))?;
        }
        Ok(())
    }
}

fn word_frequency(text: &str) -> HashMap<&str, usize> {
    let mut freq = HashMap::new();
    for word in text.split_whitespace() {
        *freq.entry(word).or_insert(0) += 1;
    }
    freq
}

fn main() {
    let a = Matrix::from_vec(vec![vec![1.0, 2.0], vec![3.0, 4.0]]).unwrap();
    let b = Matrix::from_vec(vec![vec![5.0, 6.0], vec![7.0, 8.0]]).unwrap();
    let c = a.multiply(&b).unwrap();
    println!("A * B =\n{}", c);
    println!("Transpose =\n{}", c.transpose());

    let freq = word_frequency("hello world hello rust world hello");
    println!("Frequencies: {:?}", freq);
}
