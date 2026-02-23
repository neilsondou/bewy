package com.example.demo;

import java.util.*;
import java.util.stream.Collectors;

public class TaskScheduler {

    private final PriorityQueue<Task> taskQueue;
    private final Map<String, List<Task>> taskHistory;

    public TaskScheduler() {
        this.taskQueue = new PriorityQueue<>(Comparator.comparingInt(Task::priority).reversed());
        this.taskHistory = new HashMap<>();
    }

    public void addTask(String name, int priority, Runnable action) {
        Task task = new Task(name, priority, action);
        taskQueue.offer(task);
    }

    public void executeNext() {
        Task task = taskQueue.poll();
        if (task == null) {
            System.out.println("No tasks in queue");
            return;
        }
        System.out.printf("Executing: %s (priority: %d)%n", task.name(), task.priority());
        task.action().run();
        taskHistory.computeIfAbsent(task.name(), k -> new ArrayList<>()).add(task);
    }

    public List<String> getCompletedTasks() {
        return taskHistory.values().stream()
            .flatMap(Collection::stream)
            .map(Task::name)
            .distinct()
            .sorted()
            .collect(Collectors.toList());
    }

    record Task(String name, int priority, Runnable action) {}

    public static void main(String[] args) {
        TaskScheduler scheduler = new TaskScheduler();
        scheduler.addTask("Build", 3, () -> System.out.println("Building project..."));
        scheduler.addTask("Test", 2, () -> System.out.println("Running tests..."));
        scheduler.addTask("Deploy", 1, () -> System.out.println("Deploying..."));

        while (!scheduler.taskQueue.isEmpty()) {
            scheduler.executeNext();
        }
        System.out.println("Completed: " + scheduler.getCompletedTasks());
    }
}
