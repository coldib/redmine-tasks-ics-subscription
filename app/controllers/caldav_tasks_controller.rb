require 'set'

class CaldavTasksController < ApplicationController
  # Skip CSRF check — this is a stateless API endpoint authenticated via API key
  skip_before_action :verify_authenticity_token
  # Skip session-based auth; we handle auth ourselves
  skip_before_action :check_if_login_required

  before_action :authenticate_via_api_key

  def todos
    settings = Setting.plugin_redmine_tasks_ics_subscription

    project_ids                  = Array(settings['project_ids']).map(&:to_i).reject(&:zero?)
    project_ids_with_subprojects = Array(settings['project_ids_with_subprojects']).map(&:to_i).reject(&:zero?)
    open_issues_only             = settings['open_issues_only'] == '1'

    # Collect all relevant project IDs, expanding subproject trees where configured
    all_project_ids = Set.new

    if project_ids.any?
      Project.where(id: project_ids).each do |project|
        all_project_ids << project.id
      end
    end

    if project_ids_with_subprojects.any?
      Project.where(id: project_ids_with_subprojects).each do |project|
        project.self_and_descendants.status(Project::STATUS_ACTIVE).each do |p|
          all_project_ids << p.id
        end
      end
    end

    if all_project_ids.empty?
      render plain: empty_calendar, content_type: 'text/calendar; charset=utf-8'
      return
    end

    issues = Issue
               .visible(@current_api_user)
               .where(project_id: all_project_ids.to_a)
               .where(assigned_to_id: @current_api_user.id)
               .includes(:project, :tracker, :priority, :status)

    issues = issues.open if open_issues_only

    ics = RedmineTasksIcsSubscription::IcsBuilder.new(issues, request.host).build

    response.headers['Content-Disposition'] = 'attachment; filename="redmine-tasks.ics"'
    render plain: ics, content_type: 'text/calendar; charset=utf-8'
  end

  private

  def authenticate_via_api_key
    user = find_user_from_request

    unless user&.active?
      response.headers['WWW-Authenticate'] = 'Basic realm="Redmine CalDAV Tasks"'
      render plain: 'Unauthorized: Please provide your Redmine API key as the HTTP Basic Auth username.',
             status: :unauthorized, content_type: 'text/plain'
      return false
    end

    @current_api_user = user
    User.current = user
  end

  # Supports, in order of preference:
  #   1. HTTP Basic Auth — username = API key, password = anything (standard for CalDAV clients)
  #   2. HTTP Basic Auth — username/password (regular Redmine login)
  #   3. X-Redmine-API-Key header (Redmine REST API standard)
  def find_user_from_request
    if /\ABasic /i.match?(request.authorization.to_s)
      user = nil
      authenticate_with_http_basic do |username, password|
        user = User.find_by_api_key(username)
        user ||= User.try_to_login(username, password)
      end
      user
    elsif (key = request.headers['X-Redmine-API-Key'].presence)
      User.find_by_api_key(key)
    end
  end

  def empty_calendar
    [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Redmine CalDAV Tasks Plugin//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:Redmine Tasks',
      'END:VCALENDAR'
    ].join("\r\n") + "\r\n"
  end
end
