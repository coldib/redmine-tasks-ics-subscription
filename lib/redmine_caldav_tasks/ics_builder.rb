module RedmineCaldavTasks
  class IcsBuilder
    # Maps Redmine priority position to iCalendar PRIORITY value (1=highest, 9=lowest)
    PRIORITY_MAP = {
      1 => 1, # Immediate / Urgent
      2 => 1,
      3 => 5, # Normal / Medium
      4 => 9, # Low
      5 => 9
    }.freeze

    def initialize(issues, host)
      @issues = issues
      @host   = host
    end

    def build
      lines = []
      lines << 'BEGIN:VCALENDAR'
      lines << 'VERSION:2.0'
      lines << "PRODID:-//Redmine CalDAV Tasks Plugin//EN"
      lines << 'CALSCALE:GREGORIAN'
      lines << 'METHOD:PUBLISH'
      lines << 'X-WR-CALNAME:Redmine Tasks'
      lines << 'X-WR-TIMEZONE:UTC'

      @issues.each do |issue|
        lines += vtodo_lines(issue)
      end

      lines << 'END:VCALENDAR'
      lines.join("\r\n") + "\r\n"
    end

    private

    def vtodo_lines(issue)
      lines = []
      lines << 'BEGIN:VTODO'
      lines << "UID:redmine-issue-#{issue.id}@#{@host}"
      lines << "DTSTAMP:#{format_datetime(Time.now.utc)}"
      lines << "LAST-MODIFIED:#{format_datetime(issue.updated_on.utc)}"
      lines << "CREATED:#{format_datetime(issue.created_on.utc)}"
      lines << "SUMMARY:#{escape_text("##{issue.id} #{issue.subject}")}"
      lines << "STATUS:#{vtodo_status(issue)}"
      lines << "PRIORITY:#{vtodo_priority(issue)}"
      lines << "PERCENT-COMPLETE:#{issue.done_ratio}"
      lines << "URL:#{issue_url(issue)}"

      if issue.description.present?
        description = "#{issue_url(issue)}\\n\\n#{issue.description}"
        lines << "DESCRIPTION:#{escape_text(description)}"
      else
        lines << "DESCRIPTION:#{issue_url(issue)}"
      end

      lines << "DTSTART;VALUE=DATE:#{format_date(issue.start_date)}" if issue.start_date.present?
      lines << "DUE;VALUE=DATE:#{format_date(issue.due_date)}"       if issue.due_date.present?

      lines << "CATEGORIES:#{escape_text(issue.tracker.name)}"
      lines << "COMMENT:#{escape_text(issue.project.name)}"
      lines << 'END:VTODO'
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

    def issue_url(issue)
      "https://#{@host}/issues/#{issue.id}"
    end

    # Escape special characters per RFC 5545 and fold long lines
    def escape_text(text)
      escaped = text.to_s
                    .gsub('\\', '\\\\\\\\')
                    .gsub("\r\n", '\n')
                    .gsub("\n", '\n')
                    .gsub(',', '\,')
                    .gsub(';', '\;')
      fold_line(escaped)
    end

    # RFC 5545 line folding: max 75 octets per line, continuation lines start with a space
    def fold_line(text)
      return text if text.bytesize <= 75

      result = []
      current = ''
      text.each_char do |char|
        if (current + char).bytesize > 75
          result << current
          current = ' ' + char
        else
          current += char
        end
      end
      result << current unless current.empty?
      result.join("\r\n")
    end
  end
end
