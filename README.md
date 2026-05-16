# Redmine Tasks ICS Subscription

A Redmine plugin that exposes assigned issues as a read-only ICS feed. Each user gets a personal calendar subscription showing only their own assigned issues.

> **Note:** This is a read-only ICS subscription feed, **not** a CalDAV server. Subscribe using the "Internet Calendar" or "ICS subscription" option in your client — not as a CalDAV account.

---

## Endpoints

| Endpoint | Format | Use when |
|---|---|---|
| `/caldav_tasks/redmine-tasks.ics` | VTODO | Client supports tasks/reminders (Thunderbird, iOS, Android) |
| `/caldav_tasks/redmine-events.ics` | VEVENT (all-day) | Client only shows calendar events (Outlook) |

---

## Client compatibility

| Client | VTODO (`redmine-tasks.ics`) | VEVENT (`redmine-events.ics`) | Shown as | Auth |
|---|---|---|---|---|
| **Thunderbird** | ✅ | ✅ | VTODO → Task list / VEVENT → Calendar | `?key=` in URL (see below) |
| **iOS** | ✅ | ✅ | VTODO → Reminders / VEVENT → Calendar | Credentials on subscribe |
| **Android** (ICSx⁵) | ✅ | ✅ | VTODO → Tasks / VEVENT → Calendar | Credentials on subscribe |
| **Outlook 2016+** | ❌ silently ignored | ✅ | VEVENT → Calendar events | Credentials on subscribe |

> **Outlook note:** Outlook ignores VTODO entries in ICS subscriptions entirely. Use `events.ics` instead. Only issues with a due date appear — issues without a due date are never returned by this endpoint.

---

## Requirements

- Redmine 6.x (tested; other versions may work but are untested)
- Ruby 2.7+
- REST API enabled: Administration → Settings → API → Enable REST web service

---

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/coldib/redmine-tasks-ics-subscription.git redmine_tasks_ics_subscription
```

Restart Redmine, then go to **Administration → Plugins → Configure** next to _Redmine Tasks ICS Subscription_.

---

## Configuration

Open **Administration → Plugins → Redmine Tasks ICS Subscription → Configure**.

### Project selection

| Option | Behaviour |
|---|---|
| **Include all projects** | All active projects the user has access to. Future projects included automatically. |
| **This project only** | Issues from exactly that project. |
| **Incl. subprojects** | Issues from that project and all descendants. New subprojects included automatically. |

Options can be combined. **Open issues only** — when checked, closed issues are excluded from both feeds.

---

## Subscribing

### Step 1 — Get your API key

**My account** (top-right) → **API access key** → show and copy.

### Step 2 — Choose your URL and auth method

#### Standard (iOS, Android, Outlook)

Enter the URL in your client — it will prompt for credentials:

```
https://your-redmine-host/caldav_tasks/redmine-tasks.ics    ← iOS, Android (tasks/reminders)
https://your-redmine-host/caldav_tasks/redmine-events.ics   ← Outlook (calendar events)
```

Any of these credential combinations work:

| Username | Password |
|---|---|
| API key | anything (e.g. `x`) |
| Redmine login | API key |
| Redmine login | Redmine password |

The `X-Redmine-API-Key` HTTP header is also accepted for programmatic access.

#### Thunderbird (key in URL)

Thunderbird performs CalDAV discovery before fetching the ICS file and never presents an HTTP credentials dialog. Embed the API key directly in the URL:

```
https://your-redmine-host/caldav_tasks/redmine-tasks.ics?key=YOUR_API_KEY    ← Task list
https://your-redmine-host/caldav_tasks/redmine-events.ics?key=YOUR_API_KEY   ← Calendar view
```

> **Security:** HTTPS encrypts the URL in transit — the key is not visible to network observers. It does however appear in server-side access logs (nginx, Puma). Treat this URL like a password and do not share it.

### Client-specific steps

**Thunderbird**
1. Calendar → New Calendar → On the Network
2. Enter the URL with `?key=YOUR_API_KEY` appended — no credentials dialog will appear
3. Use `redmine-tasks.ics?key=…` for the task list, `redmine-events.ics?key=…` for calendar view

**Outlook 2016 / 2019 / 365**
1. File → Account Settings → Internet Calendars → New
2. Enter the `events.ics` URL → Subscribe → enter credentials

**iOS (iPhone / iPad)**
1. Settings → Calendar → Accounts → Add Account → Other → Add Subscribed Calendar
2. Enter the `todos.ics` URL → Next → enter credentials

**Android (ICSx⁵)**
1. ICSx⁵ → + → URL → enter the `todos.ics` URL and credentials

---

## Testing with curl

Basic fetch (API key as Basic Auth username):
```bash
curl -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/redmine-tasks.ics
curl -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/redmine-events.ics
```

With API key as URL parameter (Thunderbird method):
```bash
curl "https://your-redmine-host/caldav_tasks/redmine-tasks.ics?key=YOUR_API_KEY"
```

Verbose output for debugging (shows headers, TLS handshake, response):
```bash
curl -v -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/redmine-tasks.ics
```

Check response headers only:
```bash
curl -I -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/redmine-tasks.ics
```

Expected responses:
- `HTTP/1.1 200 OK` + `Content-Type: text/calendar` → working correctly
- `HTTP/1.1 401 Unauthorized` → wrong or missing credentials
- `HTTP/1.1 200 OK` with empty calendar (only headers, no VTODO/VEVENT) → no projects configured or no assigned issues

---

## ICS feed details

### todos.ics — VTODO fields

| iCalendar field | Source |
|---|---|
| `UID` | `redmine-issue-{id}@{host}` |
| `SUMMARY` | `#{id} {subject}` |
| `STATUS` | `NEEDS-ACTION` / `IN-PROCESS` / `COMPLETED` |
| `PRIORITY` | Mapped from Redmine priority position (1=highest, 9=lowest) |
| `PERCENT-COMPLETE` | `done_ratio` |
| `DTSTART` | Issue start date (if set) |
| `DUE` | Issue due date (if set) |
| `URL` | Full URL to the issue |
| `DESCRIPTION` | Issue URL + description body |
| `CATEGORIES` | Tracker name |
| `COMMENT` | Project name |

### events.ics — VEVENT fields

| iCalendar field | Source |
|---|---|
| `UID` | `redmine-issue-{id}-event@{host}` |
| `SUMMARY` | `#{id} {subject}` |
| `DTSTART` / `DTEND` | Due date (all-day; DTEND = due date + 1 day per RFC 5545) |
| `STATUS` | `TENTATIVE` / `CONFIRMED` / `CANCELLED` |
| `URL` | Full URL to the issue |
| `DESCRIPTION` | Issue URL + description body |
| `CATEGORIES` | Tracker name |
| `COMMENT` | Project name |

All text fields are escaped and line-folded per [RFC 5545 §3.1](https://datatracker.ietf.org/doc/html/rfc5545#section-3.1).

---

## Security

- All endpoints require authentication. Unauthenticated requests receive `401 Unauthorized`.
- Each user sees only issues **assigned to them** and only from projects they have permission to view.
- `all_projects` mode uses `Project.visible(current_user)` — hidden projects are never exposed.
- CSRF protection is intentionally disabled on these endpoints (stateless API, no session cookies).

---

## File structure

```
redmine_tasks_ics_subscription/
├── init.rb                                        # Plugin registration + default settings
├── app/
│   ├── controllers/
│   │   └── caldav_tasks_controller.rb             # ICS endpoints + authentication
│   └── views/
│       └── redmine_tasks_ics_subscription/
│           └── _settings.html.erb                 # Admin settings page
├── config/
│   ├── routes.rb                                  # GET /caldav_tasks/redmine-tasks.ics + events.ics
│   └── locales/
│       ├── de.yml
│       └── en.yml
└── lib/
    └── redmine_tasks_ics_subscription/
        └── ics_builder.rb                         # iCalendar generation (VTODO + VEVENT)
```

---

## License

MIT
