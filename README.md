# KitEngine — Accounts, Cloud Projects & Web Dashboard

**Status:** Planned  
**Core philosophy:** LOCAL-FIRST. ACCOUNT-BASED CLOUD ACCESS.

## 1. The main idea

KitEngine should offer an integrated account and cloud project system accessible through:

- KitDen
- KitEngine Editor
- KitEngine Cloud Web Dashboard

All three should use the same account identity.

An account is required to access private KitEngine Cloud projects and the authenticated web dashboard.

An account is **NOT** required to use the local engine.

Users must be able to work on local projects entirely offline.

Cloud functionality adds synchronization, backup, remote project management, and account-based access.

## 2. Account requirements

A KitEngine account should eventually support:

- Registration and secure login
- Account profile
- Optional passkey or third-party sign-in
- Secure sessions
- Multiple authorized devices
- Cloud project ownership
- Cloud storage usage
- Project backup history
- Web dashboard access
- Account recovery
- Account deletion and data export

The same identity must be recognized by desktop and web applications.

Users should not need separate accounts for KitDen and the web dashboard.

## 3. KitDen integration

KitDen should provide:

- **Continue Without Account**

And:

- **Sign In to KitEngine Cloud**

After signing in, KitDen should display the user's available cloud projects.

A user should be able to:

1. Open KitDen.
2. Sign in.
3. Select Cloud Projects.
4. View the projects associated with their account.
5. Download or open a project in KitEngine.
6. Continue working locally.
7. Synchronize approved changes back to the cloud.

Cloud synchronization should be optional per project.

Local projects must not be uploaded automatically just because a user signs in.

KitDen should also manage sign-out and account-related settings.

## 4. KitEngine Editor integration

The KitEngine Editor should be usable without an account.

When signed in, the editor may provide integrated cloud functions.

**Potential controls:**

- Open Cloud Project
- Back Up to Cloud
- Sync Project
- View Backup History
- Restore Previous Version
- Resolve Sync Conflict
- Open in Web Dashboard

The editor should clearly distinguish:

- **Local Project**
- **Cloud-Synchronized Project**

A cloud project should have a local working copy.

Editing should continue when internet access is lost.

Changes can be synchronized after reconnecting.

Unresolved conflicts must not silently overwrite project files.

## 5. KitEngine Cloud Web Dashboard

KitEngine should have a separate browser-accessible dashboard.

The final website domain is not decided.

The dashboard requires signing in to a KitEngine account to access private resources.

It should be usable without installing KitDen or the editor.

### Main dashboard

**Potential sections:**

- Overview
- My Cloud Projects
- Project Backups
- Storage Usage
- Devices & Sessions
- Account Settings
- Security Settings
- Future Team Projects

The dashboard should provide a convenient way to manage cloud data from another computer or device.

### Cloud project management

Users should eventually be able to:

- See their cloud projects
- View project names and engine versions
- See the last synchronization date
- View the latest backup status
- Download a project backup
- View available backup versions
- Restore a previous version
- Rename cloud project metadata
- Remove cloud projects after confirmation
- View and manage project access permissions when collaboration exists

The website should not require a complete browser-based game editor.

**THE WEB DASHBOARD IS NOT AUTOMATICALLY A SECOND KITENGINE EDITOR.**

Its primary purpose is project and account management.

A future browser editor can be considered separately if useful.

### Browser access

The dashboard should support modern desktop browsers.

Responsive access on mobile devices is desirable for account and project management.

A phone should be able to display project information or storage usage without pretending to be a full desktop game-development workstation.

## 6. Web dashboard technology

The initial technology is not finalized.

Flutter Web is a reasonable candidate, since KitEngine Editor and KitDen are already planned around Flutter and Dart.

However, the web dashboard should use whichever supported web approach offers the best performance, accessibility, security, and maintenance experience.

The dashboard should remain a separate web application.

It should communicate with KitEngine Cloud through the same documented backend API used by KitDen and the editor.

No direct browser access to privileged database credentials.

## 7. Cloud database architecture

KitEngine should separate three storage categories.

### Local projects

Ordinary project folders and files.

**Examples:**

- KitScript files
- Scenes
- Models
- Textures
- Audio
- Shaders
- Configuration

These belong on the user's computer.

### Local application database

**Recommended:** SQLite

Used where appropriate for:

- Recent projects
- Installed engine versions
- Local metadata
- Cached cloud project lists
- Offline synchronization state
- Download history

This database belongs in the operating system's application-data directory.

It is not the user's primary project file format.

### Cloud relational database

**Recommended:** PostgreSQL

Stores structured online information such as:

- Accounts and profile metadata
- Project ownership
- Project metadata
- Cloud backup version records
- Collaboration permissions
- Device information
- Storage references
- Synchronization status

Authentication secrets and sessions should be handled securely by the chosen authentication system.

### Cloud object storage

**Recommended:** Private S3-compatible object storage

Stores:

- Project archives
- Backup snapshots
- Uploaded binary assets
- Versioned project files

Large project files should not simply be placed inside PostgreSQL rows.

The database records who owns each cloud object and where it is stored.

## 8. Where the actual cloud database lives

The production PostgreSQL database should be hosted on managed or otherwise properly secured server infrastructure.

It should **NOT** live inside:

- KitDen
- The editor installation
- An exported game
- A public GitHub repository

The application servers should communicate with the database using restricted credentials.

The clients communicate with the cloud API.

For an initial implementation, a managed PostgreSQL and object-storage platform is recommended.

The exact hosting provider, infrastructure region, and domain remain undecided.

## 9. Shared backend architecture

Both desktop and web clients must use the same backend.

**Conceptual structure:**

```text
KitDen Desktop ───────┐
                      │
KitEngine Editor ─────┼── HTTPS API
                      │       │
Cloud Web Dashboard ──┘       │
                              ▼
                      Authentication
                      Authorization
                              │
                              ▼
                      Cloud Application
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
             PostgreSQL              Object Storage
          Account metadata           Project files
          Project ownership          Backup snapshots
          Storage references         Uploaded assets
          Permissions
```

The backend should enforce ownership and access rules.

Users must not be able to view somebody else's private project merely by changing a project identifier in a URL.

## 10. Cloud project identities

Projects should have persistent identifiers independent of their visible names.

For example, a user might rename a project without changing its cloud identity.

A project's record may include:

- Project ID
- Owner account ID
- Display name
- KitEngine version
- Creation timestamp
- Last update timestamp
- Last successful synchronization
- Latest backup version
- Cloud storage usage

Cloud files should have separate identifiers and integrity checks.

Renaming a project must not destroy its backup history.

## 11. Backup and synchronization

Cloud projects should have versioned backups.

Users should be able to restore earlier versions.

A reliable synchronization system must account for:

- Offline edits
- Interrupted uploads
- Deleted files
- Renamed files
- Concurrent edits on multiple devices
- Changed project formats
- Engine version compatibility

Conflicting changes must be detected.

Where automatic merging is unsafe, users should be offered a choice.

**NO SILENTLY REPLACING PLAYER.KITSC WITH AN OLDER VERSION FROM ANOTHER LAPTOP.**

## 12. Security and privacy

Cloud accounts require appropriate security protections.

**Requirements include:**

- HTTPS
- Secure account authentication
- Secure token or session storage
- Authorization for every private resource
- Rate limiting
- Private object storage
- Encrypted transport
- Server-side access checks
- Reliable database backups
- Secret management
- Account recovery
- Session revocation
- User-controlled project deletion
- Clear data export and retention policies

Signing into KitEngine Cloud must not automatically give the optional AI Helper access to cloud projects.

Cloud project access and AI access are separate permission systems.

## 13. Kuro and cloud accounts

Kuro is the black fox mascot and the face of the optional AI Helper.

Kuro does not need to become the entire account system.

He may appear in relevant KitEngine branding, but authentication should remain a normal, predictable interface.

Kuro does not approve uploads.

Kuro does not authorize cloud deletion.

Kuro does not secretly synchronize private projects.

**HE IS NOT THE DATABASE ADMINISTRATOR.**

**HE IS A BLACK FOX.**

**HE IS JUST THERE.**

## 14. Development roadmap

The cloud system should be implemented after the fundamental local engine architecture begins functioning.

**Recommended progression:**

### Phase 0 — Local foundation

Local projects, file management, project IDs, and SQLite where useful.

### Phase 1 — Accounts and backend

Authentication, PostgreSQL, cloud API, and basic account profile.

### Phase 2 — Web dashboard

Login, project list, account controls, and basic storage information.

### Phase 3 — Cloud backup

Opt-in project uploads, private object storage, backup versions, download, and restore.

### Phase 4 — Desktop cloud integration

KitDen account login, cloud project browsing, editor integration, and synchronization.

### Phase 5 — Collaboration

Team accounts, sharing permissions, and invited project members.

### Phase 6 — Advanced services

Additional cloud tools based on actual demand and infrastructure costs.

These are planned milestones, not existing features.

## 15. Final rules

| Feature / component | Requirement |
| --- | --- |
| Local KitEngine | No account required |
| KitScript | No account required |
| KitTheme | No account required |
| Local builds and exports | No account required |
| Cloud project access | Account required |
| Authenticated web dashboard | Account required |
| Cloud backups | Account required and opt-in |
| Project sharing | Account and appropriate permissions required |
| AI Helper | Optional and separate from cloud accounts |
| Cloud database | PostgreSQL |
| Cloud project files | Private object storage |
| Local application database | SQLite where useful |

**One account. Multiple supported clients. One consistent cloud service.**

**KITENGINE CLOUD — YOUR PROJECTS, AVAILABLE WHEN YOU SIGN IN.**

And when you don't sign in?

**THE ENGINE STILL WORKS.**
