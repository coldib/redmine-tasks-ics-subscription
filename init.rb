require 'redmine'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), 'lib')

Redmine::Plugin.register :redmine_tasks_ics_subscription do
  name        'Redmine Tasks ICS Subscription'
  author      'Wolfgang Grim'
  description 'Exposes assigned Redmine issues as a read-only ICS feed (VTODO and VEVENT)'
  version     '1.0.0'
  settings :default => {
             'all_projects'                 => '0',
             'project_ids'                  => [],
             'project_ids_with_subprojects' => [],
             'open_issues_only'             => '1'
           },
           :partial => 'redmine_tasks_ics_subscription/settings'
end

require 'redmine_tasks_ics_subscription'
