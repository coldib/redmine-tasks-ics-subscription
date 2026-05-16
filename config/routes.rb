RedmineApp::Application.routes.draw do
  get  'caldav_tasks/redmine-tasks.ics',  to: 'caldav_tasks#todos',  as: 'caldav_tasks_todos'
  get  'caldav_tasks/redmine-events.ics', to: 'caldav_tasks#events', as: 'caldav_tasks_events'

  # Return 405 for CalDAV write methods so clients like Thunderbird get a clean
  # HTTP response instead of a routing error, and can fall back to ICS mode.
  match 'caldav_tasks/redmine-tasks.ics',  to: 'caldav_tasks#method_not_allowed',
        via: %i[post put patch delete]
  match 'caldav_tasks/redmine-events.ics', to: 'caldav_tasks#method_not_allowed',
        via: %i[post put patch delete]
end
