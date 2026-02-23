import { EventEmitter } from 'events';

interface Task {
  id: string;
  title: string;
  completed: boolean;
  priority: 'low' | 'medium' | 'high';
  createdAt: Date;
}

interface TaskStore {
  tasks: Map<string, Task>;
  add(task: Omit<Task, 'id' | 'createdAt'>): Task;
  remove(id: string): boolean;
  toggle(id: string): Task | null;
  getByPriority(priority: Task['priority']): Task[];
}

class TaskManager extends EventEmitter implements TaskStore {
  tasks: Map<string, Task> = new Map();
  private counter = 0;

  add(data: Omit<Task, 'id' | 'createdAt'>): Task {
    const id = `task_${++this.counter}`;
    const task: Task = {
      ...data,
      id,
      createdAt: new Date(),
    };
    this.tasks.set(id, task);
    this.emit('added', task);
    return task;
  }

  remove(id: string): boolean {
    const existed = this.tasks.delete(id);
    if (existed) this.emit('removed', id);
    return existed;
  }

  toggle(id: string): Task | null {
    const task = this.tasks.get(id);
    if (!task) return null;
    task.completed = !task.completed;
    this.emit('toggled', task);
    return task;
  }

  getByPriority(priority: Task['priority']): Task[] {
    return Array.from(this.tasks.values())
      .filter(t => t.priority === priority)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  summary(): Record<string, number> {
    const result: Record<string, number> = { total: 0, completed: 0, pending: 0 };
    for (const task of this.tasks.values()) {
      result.total++;
      task.completed ? result.completed++ : result.pending++;
    }
    return result;
  }
}

// Demo
const mgr = new TaskManager();
mgr.on('added', (t: Task) => console.log(`Added: ${t.title}`));
mgr.add({ title: 'Write tests', completed: false, priority: 'high' });
mgr.add({ title: 'Review PR', completed: false, priority: 'medium' });
console.log(mgr.summary());
