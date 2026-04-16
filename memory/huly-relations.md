# Relations & Knowledge Graph

> Operational reference for AI agents. Load this file to understand how Huly entities connect, tag hierarchies, and relation types.

---

## Relation Types

| Relation | Type | Example | Use |
|---|---|---|---|
| **Blocks** | Issue -> Issue | "Cannot deploy" BLOCKS "Launch" | Dependency chain, critical path |
| **Relates To** | Issue -> Issue | "Frontend bug" RELATES TO "API issue" | Context clustering |
| **Duplicates** | Issue -> Issue | Duplicate bug reports | Auto-close when original resolved |
| **Creates Resource** | Issue -> Client_Resource | "Set up GitHub" -> Client_Resource | Onboarding tracking |
| **Documents In** | Issue -> Knowledge_Article | Task -> related guide | Quick reference during work |
| **Involves Device** | Issue -> Smart_Home_Device | Bug -> specific device | Device-scoped debugging |
| **Part of Sprint** | Issue -> Sprint | Task -> Sprint 12 | Sprint tracking, burndown |
| **Client Assignment** | Project -> Client | Project space -> Client record | Revenue, metadata |

### Relation Rules

- Every issue that prevents another from starting must have a **Blocks** relation
- Duplicate issues: keep the one with more context, close the other with **Duplicates** link
- Onboarding tasks must link to the **Client_Resource** they create via **Creates Resource**
- Any task referencing a specific IoT device must use **Involves Device**

---

## Tag Hierarchies

### PROJECT_TYPE

Every task gets exactly ONE project type tag.

```
PROJECT_TYPE
  ├── Smart Home
  ├── Energy Management
  ├── Web Development
  ├── Mobile App
  ├── R&D
  ├── VR/AR
  └── Internal
```

**Auto-suggest rules**:

| Condition | Suggested Tag |
|---|---|
| Client = Axtech | Smart Home + Energy Management |
| Client contains "Tuya" | Smart Home |
| Project code = OAS | R&D |
| Project code = INT | Internal |

### CLIENT

Every task gets exactly ONE client tag (or "Internal").

```
CLIENT
  ├── Axtech
  ├── Tuya-ClientA
  ├── Tuya-ClientB
  ├── Ad-Hoc-Web
  └── Internal
```

### TECH_STACK

Tasks can have MULTIPLE tech stack tags.

```
TECH_STACK
  ├── Frontend
  │   ├── React
  │   ├── Vue
  │   ├── Flutter
  │   └── HTML/CSS
  ├── Backend
  │   ├── Node.js
  │   ├── Python
  │   ├── Firebase
  │   └── Custom API
  ├── Smart Home
  │   ├── Tuya SDK
  │   ├── Home Assistant
  │   ├── MQTT
  │   └── Zigbee
  └── AI/ML
      ├── OpenAI GPT
      ├── TensorFlow
      └── Custom ML
```

### PHASE

Every task gets exactly ONE phase tag.

```
PHASE
  Discovery → Design → Development → Testing → Deployment → Maintenance
```

| Phase | Description |
|---|---|
| Discovery | Requirements gathering, research, feasibility |
| Design | Architecture, UI/UX, technical design docs |
| Development | Active coding and implementation |
| Testing | QA, integration tests, UAT |
| Deployment | Release, infrastructure, go-live |
| Maintenance | Bug fixes, monitoring, support |

---

## Tag Assignment Summary

| Tag Category | Cardinality | Required |
|---|---|---|
| PROJECT_TYPE | Exactly 1 | Yes |
| CLIENT | Exactly 1 | Yes |
| TECH_STACK | 1 or more | Yes (at least one) |
| PHASE | Exactly 1 | Yes |

---

## Knowledge Graph Traversal Examples

### "What's blocking the Axtech launch?"

```
Query: CLIENT=Axtech, has outgoing BLOCKS relation
Result: Chain of blocking issues from leaf to launch task
```

### "What devices are affected by this bug?"

```
Query: Start from bug issue, follow INVOLVES_DEVICE relations
Result: List of Smart_Home_Device records with firmware/model info
```

### "What resources were created during onboarding?"

```
Query: Start from onboarding sprint tasks, follow CREATES_RESOURCE relations
Result: All Client_Resource records with types and access info
```

### "What documentation exists for this task area?"

```
Query: Start from task, follow DOCUMENTS_IN relations
Result: Knowledge_Article list from Trainings module
```

---

## Entity Relationship Diagram (textual)

```
Client
  ├── has many → Project
  │     ├── has many → Sprint
  │     │     └── contains → Issue (Part of Sprint)
  │     └── has many → Issue
  │           ├── Blocks → Issue
  │           ├── Relates To → Issue
  │           ├── Duplicates → Issue
  │           ├── Creates Resource → Client_Resource
  │           ├── Documents In → Knowledge_Article
  │           └── Involves Device → Smart_Home_Device
  ├── has many → Client_Resource
  └── has many → Smart_Home_Device
```
