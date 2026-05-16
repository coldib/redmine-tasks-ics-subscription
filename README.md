# Redmine Tasks ICS Subscription

A Redmine plugin that exposes assigned issues as a read-only ICS feed, compatible with any calendar client that supports iCalendar subscriptions (Thunderbird, iOS, Android, Outlook).

---

## Overview

This plugin adds two unauthenticated-from-the-browser, API-key-protected HTTP endpoints to your Redmine instance:

| Endpoint | Format | Best for |
|---|---|---|
| `/caldav_tasks/todos.ics` | VTODO | Thunderbird, iOS, Android |
| `/caldav_tasks/events.ics` | VEVENT (all-day) | Outlook 2016+ |

Each user sees only their own assigned issues from the projects configured in the plugin settings.

> **Note:** This is a read-only ICS subscription feed, **not** a CalDAV server. Clients that use CalDAV protocol methods (PROPFIND, PUT, DELETE, etc.) will receive errors. Subscribe using the "Internet Calendar" or "ICS subscription" option in your client — not as a CalDAV account.

---

## Why two endpoints?

**Thunderbird, iOS, Android** natively support VTODO (the iCalendar task format) and display subscribed tasks in their task/reminder views.

**Outlook 2016+** silently ignores VTODO entries in ICS subscriptions. It only renders VEVENT (calendar events). The `/caldav_tasks/events.ics` endpoint works around this by outputting issues as all-day calendar events placed on their due date. Issues without a due date are omitted from this feed.

---

## Requirements

- Redmine 6.x (tested; other versions may work but are untested)
- Ruby 2.7+
- REST API must be enabled in Redmine (Administration → Settings → API → Enable REST web service)

---

## Installation

1. Clone or copy the plugin into your Redmine plugins directory:

   ```bash
   cd /path/to/redmine/plugins
   git clone https://github.com/coldib/redmine-tasks-ics-subscription.git redmine_tasks_ics_subscription
   ```

2. Restart Redmine.

3. Go to **Administration → Plugins** and click **Configure** next to _Redmine Tasks ICS Subscription_.

---

## Configuration

Open **Administration → Plugins → Redmine Tasks ICS Subscription → Configure**.

### Project selection

| Option | Behaviour |
|---|---|
| **Include all projects** | Subscribes to all active projects the user has access to. New projects are included automatically. |
| **This project only** | Includes issues from exactly that project. |
| **Incl. subprojects** | Includes issues from that project and all its descendants. New subprojects are included automatically. |

Options can be combined. A project that appears in both columns is included once.

**Open issues only** — when checked, closed issues are excluded from both feeds.

---

## Subscribing

### Step 1 — Get your API key

Go to **My account** (top-right menu) → scroll to **API access key** → show and copy the key.

### Step 2 — Subscribe in your client

Use one of the URLs shown on the plugin configuration page:

```
webcal://your-redmine-host/caldav_tasks/todos.ics   ← Thunderbird, iOS, Android
webcal://your-redmine-host/caldav_tasks/events.ics  ← Outlook
```

When your client asks for credentials, use **any** of these combinations:

| Username | Password |
|---|---|
| API key | anything (e.g. `x`) |
| Redmine login | API key |
| Redmine login | Redmine password |

The `X-Redmine-API-Key` HTTP header is also accepted for programmatic access.

### Client-specific instructions

**Thunderbird**
1. Calendar → New Calendar → On the Network
2. Select **iCalendar (ICS)** _(not CalDAV)_
3. Enter the `todos.ics` URL → enter credentials when prompted

**Outlook 2016 / 2019 / 365**
1. File → Account Settings → Internet Calendars → New
2. Enter the `events.ics` URL → Subscribe
3. Enter credentials in the next dialog

**iOS (iPhone / iPad)**
1. Settings → Calendar → Accounts → Add Account → Other → Add Subscribed Calendar
2. Enter the `todos.ics` URL → Next → enter credentials

**Android (e.g. with ICSx⁵ / DAVx⁵)**
1. Open ICSx⁵ → + → URL
2. Enter the `todos.ics` URL and credentials

**curl (testing)**
```bash
curl -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/todos.ics
curl -u "YOUR_API_KEY:x" https://your-redmine-host/caldav_tasks/events.ics
```

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
| `DTSTART` / `DTEND` | Due date (all-day event; DTEND = due date + 1 day per RFC 5545) |
| `STATUS` | `TENTATIVE` / `CONFIRMED` / `CANCELLED` |
| `URL` | Full URL to the issue |
| `DESCRIPTION` | Issue URL + description body |
| `CATEGORIES` | Tracker name |
| `COMMENT` | Project name |

All text fields are escaped and line-folded per [RFC 5545 §3.1](https://datatracker.ietf.org/doc/html/rfc5545#section-3.1).

---

## Security

- All endpoints require authentication. Unauthenticated requests receive `401 Unauthorized` with a `WWW-Authenticate: Basic` challenge.
- Each user sees only issues **assigned to them** and only from projects they have permission to view.
- The `all_projects` mode uses `Project.visible(current_user)` — hidden projects are never exposed.
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
│   ├── routes.rb                                  # GET /caldav_tasks/todos.ics + events.ics
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
