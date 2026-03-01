const API_URL = '/api/tasks';

async function fetchTasks() {
    const res = await fetch(API_URL);
    const tasks = await res.json();
    const list = document.getElementById('taskList');
    list.innerHTML = '';
    tasks.forEach(task => {
        const li = document.createElement('li');
        li.textContent = task.title || task.name;
        list.appendChild(li);
    });
}

async function addTask() {
    const input = document.getElementById('taskInput');
    if (!input.value) return;
    await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: input.value })
    });
    input.value = '';
    fetchTasks();
}

fetchTasks();
