# Client Management System

> Operational reference for AI agents. Load this file to understand client data structures, lifecycle, and onboarding processes.

---

## Client Class Schema

```yaml
Client:
  name: text                    # e.g., "Axtech", "Tuya - ClientA"
  tier: enum client_tier        # T1, T2, T3, T4, TR&D
  industry: text
  contract_start: date
  contract_end: date
  primary_contact: person
  contact_email: text
  contact_phone: text
  tech_stack: multi-select      # Tuya SDK, Node.js, React, etc.
  revenue_model: enum           # Monthly Retainer | Per-Project | Hourly | Equity | One-Time
  monthly_value: number
  timezone: text                # CET, IST, GMT+7
  google_drive_folder: URL
  chrome_profile_name: text     # e.g., "Axtech - ThoughtSeed"
  status: enum                  # Active | On Hold | Completed | Churned
  projects: relation → Project
  devices: relation → Smart_Home_Device
  resources: relation → Client_Resource
```

---

## Client Lifecycle

| Status | Meaning | Transition Trigger |
|---|---|---|
| **Active** | Delivering work, regular communication | New contract signed |
| **On Hold** | Paused by mutual decision | Client request or internal decision |
| **Completed** | Contract fulfilled, deliverables handed over | Final invoice paid, handoff done |
| **Churned** | Lost client | Non-renewal, termination |

```
Active → On Hold → Active       (resume)
Active → Completed              (contract end)
Active → Churned                (lost)
On Hold → Churned               (abandoned)
On Hold → Completed             (wrap up remaining)
```

---

## Client Resource Types

| Resource Type | Examples |
|---|---|
| GitHub Organization | github.com/axtech-iot |
| Vercel Account | vercel.com/axtech |
| Cloudflare DNS | DNS zone management |
| Domain Registration | Registrar access |
| Google Analytics | GA4 property |
| API Key | Tuya IoT API, third-party services |
| Admin Panel | CMS, device management portal |
| Hosting Account | AWS, DigitalOcean, Firebase |
| Database | Firestore, PostgreSQL, MongoDB |

### Credential Convention

All credentials stored at:

```
1Password: Clients/{ClientName}/{ResourceType}
```

Example: `1Password: Clients/Axtech/GitHub Organization`

---

## Smart Home Device Class

```yaml
Smart_Home_Device:
  device_name: text             # e.g., "Living Room Thermostat"
  device_model: text            # e.g., "Tuya TRV-300"
  platform: enum                # Tuya IoT Platform | Axtech Energy System | etc.
  device_id: text               # Platform-specific identifier
  firmware_version: text
  api_endpoint: URL
  integration_status: enum      # See below
```

### Integration Status Flow

```
Not Started → In Progress → Testing → Deployed → Issue
```

| Status | Meaning |
|---|---|
| Not Started | Device registered but no integration work begun |
| In Progress | Active development on integration |
| Testing | Integration code complete, running QA |
| Deployed | Live in production |
| Issue | Deployed but experiencing problems |

---

## New Client Onboarding Process

1. **Duplicate template**: Copy `[TEMPLATE]` project in Huly Tracker
2. **Populate client data**: Fill Client class fields from contract/intake form
3. **Execute onboarding tasks**: Each task in the template creates corresponding resources

### Template Tasks (auto-generated on duplication)

| Task | Creates Resource |
|---|---|
| Set up GitHub organization/repo | Client_Resource: GitHub Organization |
| Configure Vercel project | Client_Resource: Vercel Account |
| Set up Cloudflare DNS | Client_Resource: Cloudflare DNS |
| Create Google Drive folder | Updates: google_drive_folder field |
| Create Chrome profile | Updates: chrome_profile_name field |
| Store credentials in 1Password | Client_Resource per credential type |
| Schedule kickoff meeting | Calendar event + meeting notes doc |
| Create client chat channel | Huly Chat channel |
| Assign PM and team | Updates: project assignments |

### Onboarding Completion Criteria

- All template tasks marked Done
- Client_Resource records exist for each provisioned service
- Chrome profile created and tested
- First sprint planned in Tracker
- Client channel active in Chat
