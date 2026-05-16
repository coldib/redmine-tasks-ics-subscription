module RedmineTasksIcsSubscription
  class IcsBuilder
    # Maps Redmine priority position to iCalendar PRIORITY value (1=highest, 9=lowest)
    PRIORITY_MAP = {
      1 => 1, # Immediate / Urgent
      2 => 1,
      3 => 5, # Normal / Medium
      4 => 9, # Low
      5 => 9
    }.freeze

    def initialize(issues, base_url)
      @issues   = issues
      @base_url = base_url
    end

    def build
      lines = cal_header
      @issues.each { |issue| lines += vtodo_lines(issue) }
      lines << 'END:VCALENDAR'
      lines.join("\r\n") + "\r\n"
    end

    def build_events
      lines = cal_header
      @issues.each do |issue|
        next unless issue.due_date.present?
        lines += vevent_lines(issue)
      end
      lines << 'END:VCALENDAR'
      lines.join("\r\n") + "\r\n"
    end

    private

    def cal_header
      [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Redmine CalDAV Tasks Plugin//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        "X-WR-CALNAME:redmine-tasks-#{host}",
        'X-WR-TIMEZONE:UTC'
      ]
    end

    def vtodo_lines(issue)
      lines = []
      lines << 'BEGIN:VTODO'
      lines << "UID:redmine-issue-#{issue.id}@#{host}"
      lines << "DTSTAMP:#{format_datetime(Time.now.utc)}"
      lines << "LAST-MODIFIED:#{format_datetime(issue.updated_on.utc)}"
      lines << "CREATED:#{format_datetime(issue.created_on.utc)}"
      lines << prop('SUMMARY',          escape_text("##{issue.id} #{issue.subject}"))
      lines << "STATUS:#{vtodo_status(issue)}"
      lines << "PRIORITY:#{vtodo_priority(issue)}"
      lines << "PERCENT-COMPLETE:#{issue.done_ratio}"
      lines << "URL:#{issue_url(issue)}"

      if issue.description.present?
        lines << prop('DESCRIPTION', escape_text("#{issue_url(issue)}\\n\\n#{issue.description}"))
      else
        lines << "DESCRIPTION:#{issue_url(issue)}"
      end

      lines << "DTSTART;VALUE=DATE:#{format_date(issue.start_date)}" if issue.start_date.present?
      lines << "DUE;VALUE=DATE:#{format_date(issue.due_date)}"       if issue.due_date.present?

      lines << prop('CATEGORIES', escape_text(issue.tracker.name))
      lines << prop('COMMENT',    escape_text(issue.project.name))
      lines << 'END:VTODO'
      lines
    end

    def vevent_lines(issue)
      lines = []
      lines << 'BEGIN:VEVENT'
      lines << "UID:redmine-issue-#{issue.id}-event@#{host}"
      lines << "DTSTAMP:#{format_datetime(Time.now.utc)}"
      lines << "LAST-MODIFIED:#{format_datetime(issue.updated_on.utc)}"
      lines << "CREATED:#{format_datetime(issue.created_on.utc)}"
      lines << prop('SUMMARY', escape_text("##{issue.id} #{issue.subject}"))
      lines << "DTSTART;VALUE=DATE:#{format_date(issue.due_date)}"
      lines << "DTEND;VALUE=DATE:#{format_date(issue.due_date + 1)}"
      lines << "STATUS:#{vevent_status(issue)}"
      lines << "URL:#{issue_url(issue)}"

      if issue.description.present?
        lines << prop('DESCRIPTION', escape_text("#{issue_url(issue)}\\n\\n#{issue.description}"))
      else
        lines << "DESCRIPTION:#{issue_url(issue)}"
      end

      lines << prop('CATEGORIES', escape_text(issue.tracker.name))
      lines << prop('COMMENT',    escape_text(issue.project.name))
      lines << 'END:VEVENT'
      lines
    end

    def vtodo_status(issue)
      if issue.closed?
        'COMPLETED'
      elsif issue.done_ratio > 0
        'IN-PROCESS'
      else
        'NEEDS-ACTION'
      end
    end

    def vevent_status(issue)
      if issue.closed?
        'CANCELLED'
      elsif issue.done_ratio > 0
        'CONFIRMED'
      else
        'TENTATIVE'
      end
    end

    def vtodo_priority(issue)
      pos = issue.priority&.position || 3
      PRIORITY_MAP[pos] || 5
    end

    def format_datetime(time)
      time.strftime('%Y%m%dT%H%M%SZ')
    end

    def format_date(date)
      date.strftime('%Y%m%d')
    end

    def host
      # Strip protocol — used only for UIDs where a bare hostname is expected
      @base_url.sub(%r{\Ahttps?://}, '')
    end

    def issue_url(issue)
      "#{@base_url}/issues/#{issue.id}"
    end

    # Escape special characters per RFC 5545
    def escape_text(text)
      text.to_s
          .gsub('\\', '\\\\\\\\')
          .gsub("\r\n", '\n')
          .gsub("\n", '\n')
          .gsub(',', '\,')
          .gsub(';', '\;')
    end

    # Build a complete property line and fold it per RFC 5545.
    # Folding must be applied to the full "PROPERTY:value" line so that
    # the property name prefix is counted toward the 75-octet limit.
    def prop(name, value)
      fold_line("#{name}:#{value}")
    end

    # RFC 5545 line folding: max 75 octets per line,
    # continuation lines begin with a single SPACE.
    def fold_line(line)
      return line if line.bytesize <= 75

      result  = []
      current = ''
      line.each_char do |char|
        if (current + char).bytesize > 75
          result  << current
          current  = ' ' + char
        else
          current += char
        end
      end
      result << current unless current.empty?
      result.join("\r\n")
    end
  end
end
