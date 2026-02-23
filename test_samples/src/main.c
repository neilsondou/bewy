#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char name[64];
    int age;
    float score;
} Student;

Student* create_student(const char* name, int age, float score) {
    Student* s = (Student*)malloc(sizeof(Student));
    if (s == NULL) return NULL;
    strncpy(s->name, name, sizeof(s->name) - 1);
    s->name[sizeof(s->name) - 1] = '\0';
    s->age = age;
    s->score = score;
    return s;
}

void print_student(const Student* s) {
    printf("Name: %s, Age: %d, Score: %.2f\n", s->name, s->age, s->score);
}

int binary_search(int arr[], int size, int target) {
    int left = 0, right = size - 1;
    while (left <= right) {
        int mid = left + (right - left) / 2;
        if (arr[mid] == target) return mid;
        if (arr[mid] < target) left = mid + 1;
        else right = mid - 1;
    }
    return -1;
}

int main() {
    Student* alice = create_student("Alice", 20, 95.5f);
    if (alice) {
        print_student(alice);
        free(alice);
    }

    int arr[] = {1, 3, 5, 7, 9, 11, 13};
    int idx = binary_search(arr, 7, 7);
    printf("Found at index: %d\n", idx);

    return 0;
}
