RedmineApp::Application.routes.draw do
  get 'caldav_tasks/todos.ics', to: 'caldav_tasks#todos', as: 'caldav_tasks_todos'
end
