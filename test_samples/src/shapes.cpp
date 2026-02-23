#include <iostream>
#include <vector>
#include <algorithm>
#include <memory>
#include <string>

template<typename T>
class Stack {
private:
    std::vector<T> data;
public:
    void push(const T& val) { data.push_back(val); }
    T pop() {
        if (data.empty()) throw std::runtime_error("Stack underflow");
        T val = data.back();
        data.pop_back();
        return val;
    }
    bool empty() const { return data.empty(); }
    size_t size() const { return data.size(); }
};

class Shape {
public:
    virtual ~Shape() = default;
    virtual double area() const = 0;
    virtual std::string name() const = 0;
};

class Circle : public Shape {
    double radius;
public:
    explicit Circle(double r) : radius(r) {}
    double area() const override { return 3.14159265358979 * radius * radius; }
    std::string name() const override { return "Circle"; }
};

class Rectangle : public Shape {
    double width, height;
public:
    Rectangle(double w, double h) : width(w), height(h) {}
    double area() const override { return width * height; }
    std::string name() const override { return "Rectangle"; }
};

int main() {
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.push_back(std::make_unique<Circle>(5.0));
    shapes.push_back(std::make_unique<Rectangle>(4.0, 6.0));

    for (const auto& shape : shapes) {
        std::cout << shape->name() << " area: " << shape->area() << std::endl;
    }

    Stack<int> stack;
    stack.push(10);
    stack.push(20);
    std::cout << "Popped: " << stack.pop() << std::endl;

    return 0;
}
