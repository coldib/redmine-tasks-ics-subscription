require 'redmine'

Redmine::Plugin.register :redmine_caldav_tasks do
  name        'Redmine CalDAV Tasks plugin'
  author      'Wolfgang Lobo'
  description 'Exposes assigned Redmine issues as VTODO items in an ICS feed (CalDAV-compatible)'
  version     '1.0.0'

  settings :default => {
             'project_ids'                  => [],
             'project_ids_with_subprojects' => [],
             'open_issues_only'             => '1'
           },
           :partial => 'redmine_caldav_tasks/settings'
end

require 'redmine_caldav_tasks'
