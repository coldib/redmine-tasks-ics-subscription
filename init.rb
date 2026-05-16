require 'redmine'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), 'lib')

Redmine::Plugin.register :redmine_tasks_ics_subscription do
  name        'Redmine Tasks ICS Subscription'
  author      'Wolfgang Lobo'
  description 'Exposes assigned Redmine issues as VTODO items in an ICS feed (CalDAV-compatible)'
  version     '1.0.0'
  settings :default => {
             'project_ids'                  => [],
             'project_ids_with_subprojects' => [],
             'open_issues_only'             => '1'
           },
           :partial => 'redmine_tasks_ics_subscription/settings'
end

require 'redmine_tasks_ics_subscription'
