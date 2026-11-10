# GYM MANAGEMENT PROJECT MASTER

**Technical handover and continuation reference**  
**Last updated:** 10 November 2026  
**Project owner / development context:** Innovex Fitness Center / Innovex Web Solutions  
**Primary development environment described in the conversation:** Windows office laptop, PowerShell, Flutter, Node.js and MySQL 8.

> **Purpose.** This document is the durable technical handover for continuing the Gym Management project in a new ChatGPT conversation. It records decisions, source paths, database facts, endpoints, implementation state, debugging history and pending work. It deliberately distinguishes verified implementation from requirements that have only been discussed. Unknown schema details are identified as unknown rather than guessed.

---

## 1. Project Overview and Objectives

The project is an Innovex Gym Management solution with a platform-level Super Admin application, a Node.js/MySQL backend and a separate Flutter application used by gym staff and members as that app is developed.

The intended product scope includes:

- Platform administration of gym organizations, branches, registered devices, licenses and platform audit activity.
- A gym operational application for branch-wise gym operations.
- Member registration and member profiles.
- Membership products and plans, including monthly, yearly and daily payment arrangements.
- Membership billing, payment recording and an approval workflow for actions that require administrator approval.
- Gym programs, program enrollment and program-specific member progress.
- Fitness progress history with member photographs and measurements.
- Role-based access control, with configurable roles and dynamic permissions.
- Auditing of important administrative and operational actions.

### Current product boundary

The platform-management foundation is substantially further along than the day-to-day gym operations application. The Super Admin Flutter app and the Node API already have organization, device and license management. The audit-log read screen has been added but still requires final lint/runtime verification. Membership, payments, programs, enrollments and fitness progress are product requirements, not confirmed completed modules in the current Flutter/API codebase.

The original design considered an organization/tenant with multiple branches. The user later said full multi-tenant complexity could be deferred initially while branch-wise operations remained necessary. The implemented platform layer nevertheless has an `organizations` boundary, organization-owned branches, licenses and devices. The current state is therefore organization-scoped at the platform/device/license level; do not assume all future operational data APIs are already tenant-isolated.

---

## 2. Technology Stack and Development Environment

### Backend

- Node.js **v24.20.0**.
- npm **v11.19.0**.
- Express.js.
- MySQL **8.0.x** (office environment reported 8.0.39 in earlier setup notes).
- `mysql2` promise API for database access (`db.query`, `db.getConnection`).
- `dotenv` for environment configuration.
- `cors` and `express.json()` in the Express server.
- `bcrypt` for password hashing in platform admin authentication.
- `jsonwebtoken` for platform-admin JWTs.
- Node `crypto` for organization code generation, SHA-256 hashes and secure random tokens.

### Flutter

- Flutter **3.47.7 stable**.
- Dart **3.13.5**.
- Windows development environment; Android SDK **36.0.0** and Android Studio were installed.
- Pixel Tablet Android emulator used during development.
- `dio` for HTTP requests.
- `flutter_secure_storage` for platform-admin token storage.
- Flutter Material 3 UI.

### Office laptop project paths

```text
%USERPROFILE%\Documents\INNOVEX WEB\Flutter Projects\
    gym_management_api\
    gym_management_super_admin\
    gym_management_app\
```

The same logical projects previously existed on the original development laptop under:

```text
D:\Personal\INNOVEX WEB\Flutter Projects\
    gym_management_api\
    gym_management_super_admin\
    gym_management_app\
```

The user explicitly said work was continuing on the office laptop and did not want to switch back to or pull to the original laptop during this development session. Do not assume the original laptop has the newest changes.

### API runtime

The API server uses `process.env.PORT || 5000` and was accessed locally at:

```text
http://localhost:5000
```

The health endpoint returned the following successful response on the office laptop:

```json
{
  "success": true,
  "api": "connected",
  "database": "connected"
}
```

The exact current Flutter API base URL is configured in `lib/core/constants/api_constants.dart`; its literal value was not included in the source excerpts available for this handover. Do not guess it. The API `.env` contains local secrets and must not be committed or pasted into chat.

---

## 3. Final Project Architecture

There are three separately versioned repositories:

| Layer | Project folder | GitHub repository |
|---|---|---|
| Backend API | `gym_management_api` | `https://github.com/arafath65/gym-management-api.git` |
| Platform Super Admin app | `gym_management_super_admin` | `https://github.com/arafath65/gym-management-super-admin.git` |
| Gym operational app | `gym_management_app` | `https://github.com/arafath65/gym-management-apps.git` |

The repositories are separate; do not assume one Git commit pushes all three.

### Logical architecture

```text
Platform Administrator
        |
        v
Flutter Super Admin App
  - Login / JWT storage
  - Dashboard
  - Organizations and branches
  - Device management
  - License management
  - Audit log viewer
        |
        | HTTPS/HTTP JSON + Bearer JWT
        v
Node.js / Express API
  - Platform-admin authentication
  - Organization and branch controllers
  - Device registration and activation
  - License lifecycle
  - Platform audit read/write
        |
        v
MySQL 8
  - organizations / branches
  - platform_admins / platform_audit_logs
  - licenses / devices
  - gym users / roles / permissions (schema exists or is planned in current design;
    operational implementation still needs verification)

Separate Flutter Gym App
  - Intended staff-side membership, payments, programs and member operations
  - Backend integration and completed feature coverage are not established
    by the latest verified source excerpts.
```

### Current tenant / branch model

- `organizations` is the platform-level gym/customer boundary.
- `branches` belongs to an organization (`organization_id` is used by the branch controller).
- Devices belong to an organization and may be assigned to a branch.
- Licenses belong to an organization and determine the allowed active-device count.
- The future operational app must consistently scope gym data to the authenticated organization and branch. That full set of operational query scopes has not yet been verified.

---

## 4. Flutter App Structure and Screens

### 4.1 Super Admin Flutter app

Project root:

```text
gym_management_super_admin/
```

Known source structure and classes:

```text
lib/
  main.dart
  core/
    constants/
      api_constants.dart
    services/
      auth_service.dart
  features/
    auth/
      login_screen.dart
    dashboard/
      dashboard_screen.dart
    organizations/
      organizations_screen.dart
      organization_edit_screen.dart
    devices/
      device_management_screen.dart
    licenses/
      license_management_screen.dart
    audit_logs/
      audit_logs_screen.dart
```

The folder and source filenames above were confirmed by actual file listings and terminal output after the patches were installed, except that the precise internals of `api_constants.dart` were not included in the excerpts.

#### `main.dart`

- Runs `GymSuperAdminApp`.
- Material 3 theme.
- Seed/primary red: `0xFFE50914`.
- Secondary/dark: `0xFF111111`.
- Home screen: `LoginScreen`.

#### Authentication

- `LoginScreen` handles platform-admin login and navigates to the dashboard after a successful login (the navigation implementation exists in the app, although only its import and dashboard integration were in the latest source excerpt).
- `AuthService` is the shared API client and token-store owner.

#### Dashboard

Class: `DashboardScreen` in `lib/features/dashboard/dashboard_screen.dart`.

Displayed counters:

- Organizations.
- Active Devices.
- Active Licenses.
- Pending Devices.

Management tiles:

- Organizations.
- Device Management.
- License Management.
- Audit Logs.

The License Management and Audit Logs tiles were initially placeholders. The License patch wired License Management, and the Audit Logs patch wired the Audit Logs screen. The dashboard refreshes organization/device/license statistics after returning from the related screens where implemented.

#### Organizations

Classes:

- `OrganizationsScreen` — list/search/status filter, organization cards and creation dialog.
- `OrganizationEditScreen` — organization details and the existing organization-level license configuration editor.

Organization creation collects name, slug, optional email/phone/address and initial license settings. License choices are `trial`, `monthly`, `yearly`, and `lifetime`; maximum devices is validated in the UI between 1 and 1000. Trial duration is configurable from 1 to 365 days. Lifetime uses no expiry date.

Important architectural note: the older organization edit flow can update the latest existing license in place through `PUT /api/organizations/:organizationId`. The dedicated License Management module is the separate workflow for new license records, renewals and history. Prefer the dedicated license module for renewals/history rather than treating organization-edit as a renewal operation.

#### Device Management

Class: `DeviceManagementScreen` in `lib/features/devices/device_management_screen.dart`.

Implemented UI behavior:

- Server-side search and pagination.
- Filters for device status, organization and branch.
- Page sizes 25, 50 and 100.
- Search debounce of approximately 450 ms.
- Request sequence IDs suppress stale search/filter responses.
- Organization and branch dropdowns; branch choices can include inactive branches for filtering.
- Responsive device card grid: two cards across at wide tablet/desktop widths (threshold 720 px); one column at narrower widths.
- Compact card header expands to show organization, branch, device UUID, last seen and activation expiry.
- Device action menu includes revoke, reactivate/regenerate activation code or cancel pending registration, depending on state.
- Activation code is displayed once to the administrator after registration/regeneration and can be copied.

#### License Management

Class: `LicenseManagementScreen` in `lib/features/licenses/license_management_screen.dart`.

Implemented and reported working by the user:

- License list and paging.
- Search.
- Filters for license type, organization and status.
- Summary counts.
- License detail view and organization license history.
- Issue a license.
- Renew the latest license by creating a new historical record.
- Change license status among active, suspended and expired.
- Responsive two-column cards on wide layouts.

Latest user-requested UI adjustment:

- Default list status is `active`.
- Status choices are `all`, `active`, `suspended`, and `expired`.
- Status dropdown is positioned beside the organization dropdown, while license type remains a separate filter.
- Selecting `All` exposes historical rows, including old expired records. Historical licenses must not be deleted just because a renewed license exists.

The user explicitly reported that License Management was working after testing a renewal and seeing both old and new records. That is intended history behavior.

#### Audit Logs

Class: `AuditLogsScreen` in `lib/features/audit_logs/audit_logs_screen.dart`.

Patch installed and formatted. Its intended features are:

- Read-only platform audit list.
- Search across action/entity/description/IP/admin/organization/entity ID.
- Action and entity-type filters.
- Organization/admin/date filtering supported by the API method.
- Date range selection.
- Pagination (25/50/100).
- Expandable audit records showing admin, organization, action/entity metadata, IP, user-agent and old/new JSON values.
- No edit/delete controls.

**Runtime status:** Flutter source exists and formatting was run. The latest shared `flutter analyze` output showed two informational lint warnings in `audit_logs_screen.dart` at lines 798 and 826 (`curly_braces_in_flow_control_structures`); no Flutter errors were reported. The user has not yet shared the post-fix analyzer result or a runtime screenshot confirming the audit list loads records.

### 4.2 Main Gym Management Flutter app

Project root:

```text
gym_management_app/
```

This is a separate repository from Super Admin.

The gym operational app is intended for organization/branch users and will eventually cover members, memberships, payments, programs, enrollments and fitness history. The project has been set up as a Flutter app. An earlier source excerpt showed a generic `GymManagementApp` and a `LoginScreen` prototype. That prototype had a local 500 ms delayed mock login and an explicit comment that backend authentication would be connected in a later phase. Therefore, that earlier login source is not evidence of a completed production authentication flow.

UI direction discussed for the gym app included a gym-themed splash screen with Innovex branding, progress indicator, tablet-friendly 2560x1600 design target, and a motivated green/black palette with a small red accent. Treat the design direction as a preference unless the current app source confirms the final implementation.

---

## 5. Backend Node.js API Architecture

### Project structure (known modules)

```text
gym_management_api/
  src/
    server.js
    config/
      db.js
    routes/
      platformAdminRoutes.js
      organizationRoutes.js
      branchRoutes.js
      deviceRoutes.js
      licenseRoutes.js
    controllers/
      platformAdminController.js
      platformDashboardController.js
      organizationController.js
      branchController.js
      deviceController.js
      deviceManagementController.js
      licenseManagementController.js
      platformAuditController.js
    middleware/
      platformAdminMiddleware.js
      licenseMiddleware.js
    services/
      platformAuditService.js
  .env                 # local secrets; do not commit
  package.json
```

Some file names and directories were directly inspected; the `licenseManagementController.js`, `licenseRoutes.js`, `platformAuditController.js` and audit screen were introduced by patches in this conversation.

### `src/server.js`

Known middleware and mounts:

```js
app.use(cors());
app.use(express.json());
app.use("/api/organizations", organizationRoutes);
app.use("/api/branches", branchRoutes);
app.use("/api/devices", deviceRoutes);
app.use("/api/platform-admin", platformAdminRoutes);
app.use("/api/licenses", licenseRoutes);
```

Also exposes:

- `GET /` — API-running response.
- `GET /api/health` — checks MySQL with `SELECT 1 AS database_connected`.

### Database connection

`src/config/db.js` supplies the shared `mysql2` connection/pool used by controllers. Mutating controller workflows use `db.getConnection()`, `beginTransaction`, `commit`, `rollback` and `release` when transaction safety is required.

### Controller style

- Express request/response handlers.
- Parameterized SQL queries.
- JSON responses with `success` and `message` fields.
- Validation before database writes.
- Transactions for sensitive multi-step actions, especially organization/license/device operations.
- `console.error` server-side logging and stable user-facing error messages.

---

## 6. MySQL Database Structure

### 6.1 Known table inventory

The platform database has these table names in the current project design/inspection history:

1. `organizations`
2. `branches`
3. `licenses`
4. `devices`
5. `platform_admins`
6. `platform_audit_logs`
7. `users`
8. `roles`
9. `permissions`
10. `role_permissions`
11. `user_roles`
12. `user_branch_access`
13. `audit_logs`

The first six support the platform-management/device/license/audit features documented here. The remaining tables are present in the database design inventory, but their complete DDL and column-level definitions were not available in the conversation excerpts. Membership/program-specific table names were not confirmed and must not be invented.

### 6.2 `organizations` — full DDL facts confirmed

| Column | Type / definition | Constraints / meaning |
|---|---|---|
| `id` | `bigint unsigned` | Primary key, auto increment |
| `name` | `varchar(150)` | Not null |
| `slug` | `varchar(100)` | Not null, unique |
| `organization_code` | `varchar(30)` | Nullable, unique |
| `email` | `varchar(150)` | Nullable |
| `phone` | `varchar(30)` | Nullable |
| `address` | `text` | Nullable |
| `status` | `enum('active','suspended','inactive')` | Not null, default `active` |
| `created_at` | `timestamp` | Nullable, default current timestamp |
| `updated_at` | `timestamp` | Nullable, current timestamp on update |

`organizations` is the parent for branch, device and license ownership in the implemented platform design. A separate full DDL excerpt for the organization table was shared.

### 6.3 `licenses` — full DDL facts confirmed

| Column | Type / definition | Constraints / meaning |
|---|---|---|
| `id` | `bigint unsigned` | Primary key, auto increment |
| `organization_id` | `bigint unsigned` | Not null; FK to `organizations.id`, `ON DELETE RESTRICT` |
| `license_type` | `enum('trial','monthly','yearly','lifetime')` | Not null, default `trial` |
| `license_status` | `enum('active','expired','suspended')` | Not null, default `active` |
| `max_devices` | `int unsigned` | Not null, default 2 |
| `starts_at` | `datetime` | Not null |
| `expires_at` | `datetime` | Nullable; `NULL` for lifetime license |
| `created_by_platform_admin_id` | `bigint unsigned` | Nullable; FK to `platform_admins.id`, `ON DELETE SET NULL` |
| `notes` | `varchar(500)` | Nullable |
| `created_at` | `timestamp` | Nullable, default current timestamp |
| `updated_at` | `timestamp` | Nullable, current timestamp on update |

Indexes confirmed:

- Primary key on `id`.
- `idx_licenses_org_status` on (`organization_id`, `license_status`).
- `idx_licenses_expiry` on (`expires_at`).
- `fk_license_platform_admin` index on (`created_by_platform_admin_id`).

Important rules:

- `lifetime` licenses cannot have an expiry date.
- A license is valid only when status is active, its start time has arrived, and its expiry is null or in the future.
- `max_devices` is validated by the License API between 1 and 1000.
- Renewals create a new row; history is preserved.

### 6.4 `platform_admins` — full DDL facts confirmed

| Column | Type / definition | Constraints / meaning |
|---|---|---|
| `id` | `bigint unsigned` | Primary key, auto increment |
| `full_name` | `varchar(150)` | Not null |
| `email` | `varchar(150)` | Not null, unique |
| `password_hash` | `varchar(255)` | Not null |
| `status` | `enum('active','inactive','locked')` | Not null, default `active` |
| `last_login_at` | `datetime` | Nullable |
| `created_at` | `timestamp` | Nullable, default current timestamp |
| `updated_at` | `timestamp` | Nullable, current timestamp on update |

### 6.5 `platform_audit_logs` — all columns confirmed; constraints partly unknown

| Column | Type / definition | Nullability / meaning |
|---|---|---|
| `id` | `bigint unsigned` | Not null; primary key |
| `platform_admin_id` | `bigint unsigned` | Not null; indexed |
| `organization_id` | `bigint unsigned` | Nullable; indexed |
| `action` | `varchar(100)` | Not null |
| `entity_type` | `varchar(100)` | Nullable; indexed |
| `entity_id` | `bigint unsigned` | Nullable |
| `description` | `text` | Nullable |
| `old_values` | `json` | Nullable |
| `new_values` | `json` | Nullable |
| `ip_address` | `varchar(45)` | Nullable |
| `user_agent` | `varchar(500)` | Nullable |
| `created_at` | `timestamp` | Nullable; default current timestamp |

Only the `INFORMATION_SCHEMA.COLUMNS` output was used for the complete column list. The full FK/index/engine DDL was truncated in the user-provided output, so do not infer unshown FK delete rules.

### 6.6 `branches` — columns observed in controller SQL; full DDL not provided

Observed branch fields:

- `id`
- `organization_id`
- `name`
- `branch_code`
- `phone`
- `address`
- `status`
- `created_at`

The controller uses `organization_id` as the organization association. Branch creation requires name and branch code; the code is uppercased and duplicate branch codes are rejected within the same organization. It returns new branches with status `active`. Full types, indexes and formal FK constraints were not verified with `SHOW CREATE TABLE`.

### 6.7 `devices` — columns observed through controllers; full DDL not provided

Fields used in API/controller queries and updates include:

- `id`
- `organization_id`
- `registered_branch_id`
- `device_uuid`
- `device_name`
- `device_type`
- `status`
- `activation_code_hash`
- `activation_expires_at`
- `device_token_hash`
- `last_seen_at`

The exact complete table definition, unique keys, FK constraints, and any additional timestamp fields were not supplied. Device states used in code are `pending`, `active`, and `revoked`.

### 6.8 User, role and permission tables — names known, full DDL not supplied

The design inventory includes:

- `users`
- `roles`
- `permissions`
- `role_permissions`
- `user_roles`
- `user_branch_access`
- `audit_logs`

Likely logical associations from their names and the user's decisions are user-to-role, role-to-permission and user-to-branch access. **This logical description is not a substitute for verified foreign keys.** Column names, unique constraints, indexes and exact relationship cardinality remain to be confirmed by retrieving each table's `SHOW CREATE TABLE` output.

### 6.9 Sample license records observed on 10 November 2026 (before later renewal test)

The user initially shared these three rows:

| License ID | Organization ID | Type | Status | Device limit | Start | Expiry |
|---:|---:|---|---|---:|---|---|
| 3 | 1 | yearly | active | 2 | 2026-11-09 20:23:39 | 2027-12-09 23:59:59 |
| 2 | 3 | lifetime | active | 1 | 2026-11-09 18:15:22 | `NULL` |
| 1 | 2 | trial | active | 5 | 2026-11-09 16:12:04 | 2026-11-23 16:12:04 |

Later the user intentionally marked a license expired and renewed it to verify history behavior. Therefore, the table above is a historical snapshot, **not a statement of the current live rows**.

### 6.10 Organization/branch data observed

An organization was created:

- Name: `Innovex Fitness Center`
- Slug: `innovex-fitness`

A branch was created:

- Name: `Colombo Main Branch`
- Branch code: `COL-001`
- Address: `Colombo 06, Sri Lanka`

The current database's numeric IDs should be read from MySQL rather than assumed in future scripts.

---

## 7. Authentication and Authorization

### Platform administrator authentication (implemented)

- Login endpoint: `POST /api/platform-admin/login`.
- Password hashes are stored in `platform_admins.password_hash` and bcrypt is installed/used by the platform-admin controller.
- Successful login returns a JWT.
- JWT role is `platform_admin` and contains `platform_admin_id` (and email in the token payload as observed by middleware).
- `authenticatePlatformAdmin` in `src/middleware/platformAdminMiddleware.js`:
  1. Requires `Authorization: Bearer <token>`.
  2. Requires `JWT_SECRET` in environment configuration.
  3. Verifies JWT.
  4. Requires `decoded.role === 'platform_admin'` and a `platform_admin_id`.
  5. Re-queries `platform_admins` and allows only an account with status `active`.
  6. Sets `req.platformAdmin = { id, email }`.
- Flutter `AuthService` stores the token in `FlutterSecureStorage` with key `platform_admin_token`.
- Authenticated Dio requests set `Authorization: Bearer $token`.
- Logout deletes the stored token.

### Gym staff/member authentication (pending verification)

The gym operational app needs its own authenticated user context, organization and branch claims, session handling and authorization checks. A complete production flow for that app was not established in the latest code excerpts.

---

## 8. Organization, Branch and User Management

### Organization management (implemented)

Controller: `organizationController.js`. Routes in `organizationRoutes.js` apply `router.use(authenticatePlatformAdmin)` to all organization routes.

Endpoints:

- `GET /api/organizations/` — list organizations and the latest license information.
- `POST /api/organizations/` — create organization and its initial license.
- `PUT /api/organizations/:organizationId` — update organization and, when license fields are supplied, update the latest license row in place.
- `PATCH /api/organizations/:organizationId/status` — set organization status (`active` or `inactive` in this controller's accepted workflow); action is audited.

Organization creation details:

- `name` and `slug` required.
- Slug normalized lowercase and constrained to letters, numbers and hyphens.
- Organization code generated as `GYM-` plus six uppercase hexadecimal characters from `crypto.randomBytes(3)`.
- Initial license can be trial/monthly/yearly/lifetime.
- Device limit 1–1000.
- Trial duration 1–365 days (default 14).
- Lifetime has no expiry.
- Creation and initial license are handled in a transaction and audit logging is used.

Organization status and license status are separate concepts. An organization can be active while its license is expired/suspended; device activation is still gated by the license check.

### Branch management (implemented, access hardening needed)

Controller: `branchController.js`. Routes:

- `GET /api/branches/:organizationId`
- `POST /api/branches/:organizationId`

The inspected `branchRoutes.js` did **not** include `authenticatePlatformAdmin` middleware, unlike organization routes. Treat this as a confirmed security hardening task before production: validate whether these routes should be protected by platform-admin authentication now and later use organization/branch authorization for tenant-side access. Do not expose unrestricted branch data to the public unintentionally.

Branch create requires `name` and `branch_code`; branch code is uppercased and duplicate codes for the same organization return HTTP 409. Phone/address are optional.

### User management

The `users` table and role association tables are in the database design inventory, but a complete user CRUD UI/API implementation was not verified in the latest conversation. This section remains pending beyond the platform-admin user account.

---

## 9. Roles and Dynamic Permissions

User decisions:

- Initial operational roles: `Admin`, `Cashier`, `Receptionist`.
- Must support adding custom roles and permissions rather than permanently hard-coding all permissions.
- Actions in the gym application should be permission-guarded.
- Branch access must be accounted for.
- Audit logging should cover important actions.

Table names in the design inventory:

- `roles`
- `permissions`
- `role_permissions`
- `user_roles`
- `user_branch_access`

**Implementation state:** database table names were part of the schema inventory, but the actual column definitions, API endpoints, Flutter screens, permission-checking middleware/helpers and enforcement coverage were not demonstrated in the current conversation. Treat dynamic RBAC as a planned/partially scaffolded foundation, not a completed production authorization system.

Required future enforcement points include backend API authorization (the authoritative check) and Flutter UI visibility/disablement (for user experience only). Hiding a button in Flutter must never be the only security boundary.

---

## 10. Device Registration and Validation

### Device registration (implemented)

Platform Admin registration endpoint:

- `POST /api/devices/register`
- Required body fields include `organization_id`, `device_uuid`, `device_name`, and `device_type`.
- `registered_branch_id` is optional.
- Known device types in Flutter: `android_tablet`, `android_mobile`, `other`.

The registration controller validates organization and branch ownership, checks organization/license state and current active-device quota, inserts a pending device, and returns an activation code. Activation code is stored as a SHA-256 hash, with a 24-hour expiry. The plaintext code is returned to the admin once for sharing.

### Device activation (implemented)

Endpoint:

- `POST /api/devices/activate`

This endpoint is intentionally separate from platform-admin routes and is protected by `checkOrganizationLicense` middleware plus `activateDevice` controller logic.

Observed activation flow:

1. Require `organization_id`, `device_uuid`, and `activation_code`.
2. Begin a DB transaction.
3. Lock the latest organization license (`FOR UPDATE`).
4. Require active status, started license and non-expired license.
5. Count active devices and enforce `max_devices`.
6. Hash the supplied activation code and find matching pending device.
7. Reject invalid, expired, or non-pending activation.
8. Generate a 32-byte random device token and hash it with SHA-256 for DB storage.
9. Set device status to `active`; store token hash; clear activation code hash and expiry; update `last_seen_at`.
10. Commit and return the plaintext device token once to the activating app.

The device token is not stored plaintext in the database.

### Device management endpoints

- `GET /api/devices/` — list with server-side pagination and filters.
- `POST /api/devices/register` — register pending device and return activation code.
- `POST /api/devices/:deviceId/activation-code` — regenerate activation code / reactivate revoked device flow in the management controller.
- `PATCH /api/devices/:deviceId/revoke` — revoke a device.

All management endpoints are individually protected by `authenticatePlatformAdmin`; the `/activate` route remains the gym-app activation flow.

### Device list query behavior

Known filters: `status`, `organizationId`, `branchId`, `search`, `page`, `limit`.

Page size values: 25, 50, 100. The response includes:

- `devices`
- `pagination` (`page`, `limit`, `total`, `totalPages`, `hasPreviousPage`, `hasNextPage`)
- `statusCounts` (`all`, `pending`, `active`, `revoked`)
- `filters`

The status counts intentionally ignore the currently selected status while respecting the other filters, so dashboard/filter totals do not collapse to just the selected status.

---

## 11. Activation Code and License Management

### License types and states

Allowed types from the actual MySQL enum and API validation:

- `trial`
- `monthly`
- `yearly`
- `lifetime`

Allowed states:

- `active`
- `expired`
- `suspended`

A lifetime license has `expires_at = NULL`.

### License middleware

`src/middleware/licenseMiddleware.js` checks the latest license for an organization and blocks activation when:

- No license exists.
- License status is not active.
- Current time is before `starts_at`.
- `expires_at` has passed.

It sets the validated license context on the request (`req.organizationLicense`) for downstream use.

### Dedicated License API (implemented by patch)

Mounted at `/api/licenses` in `src/server.js`; `licenseRoutes.js` applies `router.use(authenticatePlatformAdmin)` to all routes.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/licenses/` | Paginated/searchable/filterable license list |
| GET | `/api/licenses/:licenseId` | License detail and organization license history |
| POST | `/api/licenses/` | Issue a license |
| POST | `/api/licenses/:licenseId/renew` | Renew latest license by inserting a new row |
| PATCH | `/api/licenses/:licenseId/status` | Change status to active/suspended/expired |

List filters include `search`, `status`, `licenseType`, `organizationId`, `page`, and `limit`. Returned license rows include organization fields, `effective_status` and `is_latest`; response also includes status counts and pagination.

Important logic in `licenseManagementController.js`:

- `validateMaxDevices`: integer 1–1000.
- Trial duration: 1–365 days; default 14 days.
- Monthly: 30 days.
- Yearly: 365 days.
- Lifetime: no expiry.
- Optional explicit expiry format: `YYYY-MM-DD`.
- `getLicenses` calculates `effective_status = expired` for an active row whose expiry has passed, even before a manual status update.
- `getLicenseById` returns the selected license and all licenses for that organization, newest first.
- `createLicense` prevents issuing another current active license; if the latest active license is no longer valid, it marks that old row expired, then inserts the new license.
- `renewLicense` only allows the latest license to be renewed, inserts a new license row and keeps previous rows as history. When no custom expiry is specified, the new expiry extends from `GREATEST(NOW(), previous expires_at)` by the selected plan duration. It starts the new license immediately so latest-license middleware recognizes it as valid.
- Status changes are audited. The API supports `active`, `suspended`, `expired`; UI should avoid offering reactivation as a way to bypass an expired date when renewal is the intended path.

### License audit actions

Known action names used in license controller:

- `LICENSE_CREATED`
- `LICENSE_RENEWED`
- `LICENSE_SUSPENDED`
- `LICENSE_EXPIRED`
- `LICENSE_REACTIVATED`

License changes write `platform_audit_logs` in the same transaction as the license mutation.

### Older organization-edit license behavior

`updateOrganization` has an optional license configuration path which updates the existing latest license row in place if one exists (or inserts one if none exists). That path is primarily part of organization editing; it is not the dedicated historical renewal workflow. Preserve this distinction.

---

## 12. Audit Logs

### Write service (existing)

File: `src/services/platformAuditService.js`.

Export: `writePlatformAuditLog(connection, data)`.

Data accepted:

- `platformAdminId`
- `organizationId` (optional/null)
- `action`
- `entityType`
- `entityId`
- `description`
- `oldValues`
- `newValues`
- `ipAddress`
- `userAgent`

It requires a DB transaction connection, a valid platform admin ID and an action. JSON old/new values are serialized. User agent is limited to 500 characters. It inserts into `platform_audit_logs`.

The established pattern is to call audit write using the same transaction connection as the mutation, so failure to write the audit log rolls back the associated change.

### Read API (added by patch)

Controller: `src/controllers/platformAuditController.js`.  
Handler: `getPlatformAuditLogs`.

Endpoint:

- `GET /api/platform-admin/audit-logs`

Protected by `authenticatePlatformAdmin` in `platformAdminRoutes.js`.

Query parameters:

- `search`
- `action`
- `entityType`
- `organizationId`
- `platformAdminId`
- `fromDate` (`YYYY-MM-DD`, inclusive)
- `toDate` (`YYYY-MM-DD`, inclusive)
- `page`
- `limit` (25, 50, 100)

Response fields:

- `success`
- `auditLogs`
- `pagination`
- `actions`
- `entityTypes`
- `filters`

Joins audit rows to `platform_admins` for admin name/email and optionally to `organizations` for organization name/code. Results sort descending by `created_at`, then `id`. Search covers action, entity type, description, IP, admin name/email, organization name/code and entity ID.

### Flutter read screen (added by patch)

- `lib/features/audit_logs/audit_logs_screen.dart`
- `AuthService.getPlatformAuditLogs(...)` (method added to `auth_service.dart`; exact method body is in installed source and patch file).
- Dashboard Audit Logs tile now navigates to `AuditLogsScreen`.
- Intended read-only audit cards/detail expansion, filters and old/new JSON display.

**Verification status:** the user ran `dart format` on the audit screen, auth service and dashboard. `flutter analyze` reported two info-level `curly_braces_in_flow_control_structures` warnings at `audit_logs_screen.dart:798` and `:826`, and no errors. A later clean analyzer result and successful live data load have not yet been shared.

---

## 13. Membership Plans and Membership Management

### Confirmed product requirements

The user described these membership options:

- Monthly payment plan.
- Yearly plan, with Gold and Silver variants.
- Daily payment plan.
- Couple package, available monthly or yearly: one person pays and the second person is included free.
- Membership records need to associate the member/person, plan and validity/payment period.

These are requirements discussed for the Gym Management product. The current conversation does not establish a completed MySQL schema, Node API, or Flutter membership-management module for them.

### Important modeling points for future implementation

The couple package must not be modeled as an ordinary two-paid-member package: one paid membership should cover the primary member and one linked complimentary participant. The exact schema and business rules have not yet been designed/approved in this conversation; implement only after deciding how the primary and included member are linked and how renewal/cancellation works.

Gold/Silver yearly plan pricing, tax/discount rules, trial/concession rules and daily plan validity semantics have not been supplied and must be collected before hard-coding them.

---

## 14. Membership Payment and Approval Workflow

### Requirements / discussions

- Support daily, monthly and yearly membership payment models.
- Preserve the difference between plan price, amount due, amount paid, balance and payment status in future billing logic.
- Some membership creation or actions require an admin approval dialog/workflow; the exact final approval rules have not been verified.

### Earlier code/debugging note

A previous conversation contained Java/Android code using `CreateMembershipActivity`, with a `btnCreateMembership.setOnClickListener(v -> createMembership())` flow and an unresolved compile-time call:

```text
Cannot resolve method 'showAdminApprovalDialog' in 'CreateMembershipActivity'
```

This was an earlier Java activity-level implementation/prototype. It is not evidence that the current Flutter Gym App has a completed approval workflow. The available handover context does not prove the final resolution of that Java method error. Do not carry that method name into the Flutter app without first inspecting the current implementation.

### Pending design decisions

- Which operations require approval (membership creation, discount, backdated start, complimentary person, refund, waiver, manual payment correction, etc.).
- Who can approve and whether creator and approver must be different users.
- Approval statuses and rejection/rework behavior.
- Whether payment must be collected before or after approval.
- How approvals are audited.

---

## 15. Gym Programs and Enrollments

Confirmed requirement examples:

- Time-bound fitness programs such as a **60-day weight-loss program**.
- Members should be enrolled in programs.
- Program duration, enrollment dates, program status, and member results should be managed.

No final program tables, APIs, Flutter screens or complete enrollment workflows were confirmed in the current conversation. Do not claim these are implemented.

Future design should clarify whether a program is organization-wide or branch-specific, capacity limits, enrollment eligibility, program-specific fees, trainer assignment, start/end dates, attendance/checkpoints and completion status.

---

## 16. Member Profiles and Fitness Progress History

Confirmed requirements:

- Member profile with profile image.
- Fitness/growth history over time.
- Three side/progress images per recorded checkpoint were discussed.
- Measurement examples: waist, arms and chest.

No confirmed final member table schema, photo-storage design, progress-measurement schema, upload API, or UI was supplied. These remain pending.

Future implementation should distinguish immutable historical measurement snapshots from current profile values. Image storage strategy (local filesystem/object storage/database references), maximum sizes, access control and retention have not yet been decided.

---

## 17. API Endpoints and Request/Response Structures

The following are the endpoints confirmed by inspected routes and installed patches. All platform-admin protected endpoints require:

```http
Authorization: Bearer <platform-admin-jwt>
Content-Type: application/json
```

### Platform admin

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/platform-admin/login` | Public | Admin login; returns JWT |
| GET | `/api/platform-admin/dashboard-stats` | Platform admin | Dashboard counts |
| GET | `/api/platform-admin/audit-logs` | Platform admin | Read audit history |

Dashboard stats response fields observed by Flutter:

```json
{
  "success": true,
  "stats": {
    "active_devices": 0,
    "active_licenses": 0,
    "pending_devices": 0
  }
}
```

Numbers above are illustrative response shape only, not current data.

### Organizations

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/organizations/` | Platform admin | List organizations |
| POST | `/api/organizations/` | Platform admin | Create organization and initial license |
| PUT | `/api/organizations/:organizationId` | Platform admin | Update organization and optional existing license config |
| PATCH | `/api/organizations/:organizationId/status` | Platform admin | Change organization active/inactive status |

Create body fields observed:

```json
{
  "name": "Innovex Fitness Center",
  "slug": "innovex-fitness",
  "email": null,
  "phone": null,
  "address": null,
  "licenseType": "trial",
  "trialDays": 14,
  "maxDevices": 2,
  "expiresAt": null,
  "notes": null
}
```

This is a shape based on controller/UI fields; use real organization data, and for lifetime use no expiry date.

### Branches

| Method | Path | Auth confirmed in route | Purpose |
|---|---|---|---|
| GET | `/api/branches/:organizationId` | No auth middleware visible in inspected route | List organization branches |
| POST | `/api/branches/:organizationId` | No auth middleware visible in inspected route | Create branch |

The missing route-level auth is a security follow-up, as discussed in section 8.

### Devices

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/devices/activate` | Organization license middleware; not platform-admin JWT | Activate gym app device |
| GET | `/api/devices/` | Platform admin | Search/filter/paginate devices |
| POST | `/api/devices/register` | Platform admin | Register pending device |
| POST | `/api/devices/:deviceId/activation-code` | Platform admin | Regenerate code/reactivate flow |
| PATCH | `/api/devices/:deviceId/revoke` | Platform admin | Revoke device |

Register body observed from Flutter:

```json
{
  "organization_id": 1,
  "registered_branch_id": null,
  "device_uuid": "device-unique-id",
  "device_name": "Front Desk Tablet",
  "device_type": "android_tablet"
}
```

Activation body observed in the controller:

```json
{
  "organization_id": 1,
  "device_uuid": "device-unique-id",
  "activation_code": "one-time-code"
}
```

Successful activation returns a `device_token` once. Store it securely in the gym device app; the DB stores its hash.

### Licenses

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/licenses/` | Platform admin | List/search/filter licenses |
| GET | `/api/licenses/:licenseId` | Platform admin | Detail + organization history |
| POST | `/api/licenses/` | Platform admin | Issue new license |
| POST | `/api/licenses/:licenseId/renew` | Platform admin | Renew latest license, append history row |
| PATCH | `/api/licenses/:licenseId/status` | Platform admin | Set active/suspended/expired |

Create request shape used by Flutter:

```json
{
  "organizationId": 1,
  "licenseType": "yearly",
  "maxDevices": 2,
  "trialDays": null,
  "expiresAt": null,
  "notes": "Optional note"
}
```

Renew body can specify `licenseType`, `maxDevices`, `trialDays`, `expiresAt` and `notes`; controller defaults missing plan/device fields from the previous license, except trial duration defaults per validation. Status body:

```json
{ "status": "suspended" }
```

License list response includes:

```json
{
  "success": true,
  "licenses": [],
  "pagination": {},
  "statusCounts": {
    "all": 0,
    "active": 0,
    "suspended": 0,
    "expired": 0
  },
  "filters": {}
}
```

### Audit logs

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/platform-admin/audit-logs` | Platform admin | Read-only audit query |

Query keys: `search`, `action`, `entityType`, `organizationId`, `platformAdminId`, `fromDate`, `toDate`, `page`, `limit`.

Response keys: `success`, `auditLogs`, `pagination`, `actions`, `entityTypes`, `filters`.

### Health / root

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/` | Public | API running message |
| GET | `/api/health` | Public | API + MySQL connectivity check |

---

## 18. Completed Development Tasks

### Platform/API

- Node/Express API initialized and connected to local MySQL 8.
- Platform-admin table and login controller/authentication flow implemented.
- JWT middleware validates platform-admin identity and active account status.
- Organization create/list/update/status flow implemented.
- Organization code generation and initial license creation implemented.
- Branch list/create API implemented.
- Device registration and activation flow implemented, including license/device limit checks.
- Activation code hashing and expiry, device token hashing and one-time return behavior implemented.
- Device management list filtering and server-side pagination implemented.
- Dedicated license management controller/routes added.
- License history, renewals, state changes and audit integration implemented in the patch.
- Platform audit writer existed; read/list endpoint added.
- API health endpoint returned API and database connected on office laptop.

### Super Admin Flutter

- Login and dashboard screens.
- Organization listing, searching, create and edit screens.
- Device management screen with server filters, pagination, responsive cards and actions.
- License management screen with list, filters, detail/history, issue, renewal and status actions; user reported it works.
- Audit Logs screen and dashboard navigation added; formatted and analyzed, pending final analyzer/runtime confirmation.

### Environment / repository setup

- Office laptop repositories cloned into `Documents\INNOVEX WEB\Flutter Projects`.
- Flutter dependencies resolved (`flutter pub get`).
- Earlier Super Admin Flutter analyze completed with no issues before later module additions.
- Super Admin UI changes pushed previously in commit `6d7a5ca`, message `Improve device management cards and search`.

---

## 19. Errors Encountered and Their Confirmed Solutions

### 19.1 MySQL and API

- Office API health endpoint ultimately returned `success: true`, API connected and database connected. This confirms the current API process was able to query MySQL at that time.
- Do not confuse this with the separate Client Workflow System MySQL Workbench issue from another project; that was not confirmed as a Gym Management API issue.

### 19.2 npm bcrypt install-script approval

- npm 11 prompted for dependency lifecycle script approval for `bcrypt@6.0.0`.
- The office API package configuration was updated with:

```json
{
  "allowScripts": {
    "bcrypt@6.0.0": true
  }
}
```

- This change was intentional. Preserve it; do not remove it as cleanup without checking current npm behavior.

### 19.3 Device management UI/search

- Initial device listing was improved to server-side filtering and pagination rather than loading/filtering all records in Flutter.
- Search debounce and request-sequence checks were added to avoid outdated requests overwriting newer results.
- Responsive card layout was changed to show two cards across at wide widths and one card at narrow widths. Card header click expands only the selected card's details.
- The user subsequently said the device screen was okay and pushed the Super Admin repo change in commit `6d7a5ca`.

### 19.4 License Management installation

- First PowerShell installer invocation failed because the ZIP extracted into a nested `license-management-flutter-patch` folder. Resolved by recursively locating `install_license_management.ps1` and invoking its full path.
- Flutter patch installed successfully and created timestamped backups for `auth_service.dart` and `dashboard_screen.dart`.
- Initial `flutter analyze` reported three info-level curly-brace lints, not compilation errors. `dart fix --apply` was recommended.
- License filter patch attempt 1 stopped before save because its regex did not match the actual installed widget structure.
- After inspecting the real code, a targeted move script was supplied. That script left a standalone comma in the search-row child list; a targeted cleanup removed that comma. The user later reported License Management was working.
- The design requirement is to preserve old expired rows and make active the initial filter, not to delete historical rows.

### 19.5 Audit Logs module

- The API audit table schema output was initially truncated; this was resolved by querying `INFORMATION_SCHEMA.COLUMNS` to obtain all column names/types.
- Audit patch added a new read controller and route, and Flutter screen/service/dashboard integration.
- Latest user-shared `flutter analyze` output reports only two informational `curly_braces_in_flow_control_structures` warnings at lines 798 and 826 of `audit_logs_screen.dart`; no errors. No clean final analysis or runtime test result has yet been shared.

### 19.6 Earlier membership Java activity issue

- `CreateMembershipActivity` produced `Cannot resolve method 'showAdminApprovalDialog'`. This relates to earlier Android/Java activity code and has no confirmed resolution in the available project history. Verify the code before claiming it was fixed or porting it to Flutter.

---

## 20. Important Source Code Changes

### API

- `src/middleware/platformAdminMiddleware.js`: Bearer JWT validation, role check, DB check for active platform admin, sets `req.platformAdmin`.
- `src/services/platformAuditService.js`: `writePlatformAuditLog(connection, data)`, inserts audit rows with JSON snapshots in same transaction.
- `src/controllers/organizationController.js`: organization CRUD/status; creates initial license; updates latest license in organization-edit pathway; audit logging.
- `src/controllers/branchController.js`: branch listing and creation scoped by `organization_id`.
- `src/controllers/deviceManagementController.js`: list/search/filter/pagination; registration; activation-code regeneration; revoke. The device list was specifically changed to server-side pagination/search and status counts.
- `src/controllers/deviceController.js`: `activateDevice` with transaction, latest-license lock, active-device quota check, one-time activation code check and token hash storage.
- `src/middleware/licenseMiddleware.js`: validates the current/latest organization license before device activation.
- `src/controllers/licenseManagementController.js`: dedicated license list/details/create/renew/status behavior.
- `src/routes/licenseRoutes.js`: all routes protected with platform-admin auth.
- `src/controllers/platformAuditController.js`: `getPlatformAuditLogs` read endpoint.
- `src/routes/platformAdminRoutes.js`: mounts protected dashboard stats and audit logs alongside public login.
- `src/server.js`: mounts `/api/organizations`, `/api/branches`, `/api/devices`, `/api/platform-admin`, `/api/licenses` and health route.

### Super Admin Flutter

- `lib/core/services/auth_service.dart`: shared Dio client; token storage; organization/dashboard/device/branch/license/audit API methods.
- `lib/features/devices/device_management_screen.dart`: server-side filtering/pagination, search debounce, race suppression, organization/branch filters, expandable responsive cards and device actions.
- `lib/features/licenses/license_management_screen.dart`: dedicated license lifecycle UI and filter layout.
- `lib/features/audit_logs/audit_logs_screen.dart`: read-only audit viewer.
- `lib/features/dashboard/dashboard_screen.dart`: management tile navigation for Organizations, Device Management, License Management and Audit Logs; dashboard statistics.

### Git-sensitive changes to preserve

- The API `package.json` bcrypt allowScripts setting is intentional.
- `src/controllers/deviceManagementController.js` has intentional office-laptop device list pagination/search changes.
- The API changes were reported as uncommitted at the point of earlier inspection; current Git status must be checked before committing.
- The Super Admin repository had a prior pushed commit `6d7a5ca`, but later License and Audit patches were added afterward. Their current commit status must be checked locally.
- Do not run `git reset --hard`, `git checkout -- .`, `git clean -fd`, or broad restore commands to resolve future Git conflicts.

---

## 21. Current Development Status (10 November 2026)

| Area | Status | Evidence / qualification |
|---|---|---|
| API project setup and MySQL connection | **Working** | `/api/health` returned API/database connected |
| Platform admin login/JWT | **Implemented** | middleware and Flutter `AuthService` inspected |
| Organization management | **Implemented** | routes/controller and Flutter screens inspected |
| Branch list/create | **Implemented, hardening needed** | routes exist; inspected router lacked auth middleware |
| Device registration/activation | **Implemented** | transaction, license check and hashed-code/token flow inspected |
| Device Management UI | **Implemented** | user said screen was okay; pagination/search/responsive behavior in source |
| License API | **Implemented in patch** | dedicated routes/controller present in patch and installed server mount reported |
| License Management UI | **Working per user** | user explicitly said all working fine and later “license management also done” |
| Platform audit writer | **Implemented** | `platformAuditService.js` inspected |
| Platform audit read API | **Added; runtime verification pending** | patch provides controller/route; user ran Flutter format/analyze |
| Audit Logs Flutter screen | **Added; final validation pending** | analyze reported 2 info lints and no errors |
| Dynamic RBAC | **Planned/partially scaffolded** | table names and requirements known; no complete verified implementation |
| Gym user management | **Pending verification** | no completed CRUD/auth screen/API confirmed |
| Membership plans/management | **Requirements defined; implementation unverified** | monthly/yearly/daily, gold/silver, couple free companion |
| Membership payments/approval | **Pending** | rules not finalized; earlier Java method issue not confirmed resolved |
| Programs/enrollments | **Requirements defined; implementation pending** | 60-day weight-loss example |
| Member profile/progress history | **Requirements defined; implementation pending** | image + measurements; storage/schema/API absent |

---

## 22. Pending Development Tasks

### Immediate platform tasks

1. Finish Audit Logs verification: clear two lint warnings, run `flutter analyze`, run Node syntax checks, test the authenticated endpoint and verify list/search/filter/expand data in the Super Admin app.
2. Confirm the Audit Logs API is mounted and reads current records from the office MySQL database.
3. Review `branchRoutes.js`: add appropriate authentication/authorization before production, and define whether branches are accessible to platform admin only or also organization staff through tenant authorization.
4. Retrieve full DDL for `branches`, `devices`, `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_branch_access` and `audit_logs`; include indexes, FKs and delete rules in the next documentation revision.
5. Audit transaction and audit-log coverage for all sensitive platform and operational mutations.
6. Check local Git status in all three repos and commit/push the intended module work without staging unrelated changes.

### Operational app tasks

7. Complete the Gym App authentication/session/device-token handling and organization/branch context.
8. Implement backend-enforced tenant/branch scoping for gym data.
9. Finish dynamic role/permission CRUD, role assignment, branch access and server-side permission middleware.
10. Implement member CRUD and profile image handling.
11. Finalize membership plan data model (monthly, yearly Gold/Silver, daily and couple plan with one complimentary participant).
12. Implement membership creation, lifecycle, renewals, freeze/cancel rules and approvals.
13. Implement payments, partial payments/balances, payment methods, receipts/refunds and reconciliation rules.
14. Define who approves which actions, approval state transitions, separation of duties and audit history.
15. Implement program management and enrollment, including the example 60-day weight-loss program.
16. Implement member progress snapshots, measurement history (waist/arms/chest etc.), photo upload/storage, retention and access control.
17. Add operational `audit_logs` behavior if that table is intended for gym-side/user actions (confirm exact schema and ownership model first).
18. Add tests: unit/controller tests, database integration tests, API auth tests, device concurrency/quota tests, Flutter widget tests and an end-to-end tablet workflow.

### Production readiness

- Keep secrets out of Git; verify `.env` is ignored.
- Protect branch routes and all organization-bound APIs.
- Add rate limiting and suitable login protection.
- Define production CORS, HTTPS, backups, migrations, monitoring and log retention.
- Validate concurrent device activation and license renewal behavior against real MySQL transactions.
- Define secure image storage and backup policies before member progress photos are released.

---

## 23. Exact Next Development Step

**Immediate task: finish verification of the Audit Logs module.** Do not begin membership tables or redesign the Gym App before confirming that the latest platform-management feature is stable.

On the office laptop:

1. In the Super Admin project, fix the two informational lints only:

```powershell
Set-Location "$HOME\Documents\INNOVEX WEB\Flutter Projects\gym_management_super_admin"

dart fix --apply --code=curly_braces_in_flow_control_structures .\lib\features\audit_logs\audit_logs_screen.dart
dart format .\lib\features\audit_logs\audit_logs_screen.dart
flutter analyze
```

2. In the API project, run syntax validation and restart the API:

```powershell
Set-Location "$HOME\Documents\INNOVEX WEB\Flutter Projects\gym_management_api"

node --check .\src\controllers\platformAuditController.js
node --check .\src\routes\platformAdminRoutes.js
node --check .\src\server.js
npm run dev
```

3. In the Super Admin app, open **Audit Logs** and verify:
   - existing organization, device and license events load;
   - newest records appear first;
   - search works;
   - action/entity/date filters work;
   - pagination works;
   - expandable records show old/new values and request metadata;
   - the screen remains read-only.

4. If any operation fails, capture the exact API response and server console error. Do not paste JWTs, passwords, `.env` values or device tokens.

5. Only after verification, inspect `git status --short` separately in the API and Super Admin repositories. Commit the desired module changes explicitly; preserve the bcrypt `allowScripts` approval and device server-pagination changes.

---

# CURRENT DEVELOPMENT HANDOVER

## Current position

As of 10 November 2026, development is on the **office laptop**. The latest platform feature added is the Audit Logs module. License Management was reported working by the user. Device Management, Organization Management and the platform dashboard are in place.

The API health endpoint was confirmed to report both API and database connected. The Audit Logs Flutter source was installed and formatted. The latest shared analyzer output showed two info-only lint warnings at `audit_logs_screen.dart` lines 798 and 826; no Flutter errors were reported. The final analyzer pass and live Audit Logs runtime test are still outstanding. The user has not shared a confirmed Node syntax-check/runtime result for the new audit controller after installation.

## Exact next task

**Finish Audit Logs lint cleanup and runtime verification**, following Section 23. Then check Git status and commit/push the verified work.

## Paths to use

```text
API:
%USERPROFILE%\Documents\INNOVEX WEB\Flutter Projects\gym_management_api

Super Admin Flutter:
%USERPROFILE%\Documents\INNOVEX WEB\Flutter Projects\gym_management_super_admin

Gym App Flutter:
%USERPROFILE%\Documents\INNOVEX WEB\Flutter Projects\gym_management_app
```

## Critical continuity rules for the next conversation

- Continue from the office-laptop state; do not tell the user to switch to the original laptop or pull there.
- Do not assume membership, payment approval, program, enrollment, or progress-photo modules are complete.
- Do not invent missing database columns or FK constraints; request actual DDL when implementing those modules.
- Keep license renewals as new records; never overwrite/delete historical renewal rows in the dedicated License Management flow.
- Preserve the current API device list pagination/search change and the intentional bcrypt npm lifecycle-script approval.
- Keep platform audit writes inside the same transaction as the business mutation.
- Protect all operational APIs on the server. Flutter UI visibility is not a substitute for API authorization.
- Use the existing Flutter `AuthService` and secure JWT handling for the Super Admin app; avoid creating duplicate HTTP/auth clients without a reason.
- Use PowerShell commands and inspect exact source before applying automated edits. Back up files and stage only intended Git paths.
- Never publish `.env`, JWTs, passwords, activation codes or device tokens.

## GitHub repositories

```text
API:
https://github.com/arafath65/gym-management-api.git

Super Admin:
https://github.com/arafath65/gym-management-super-admin.git

Gym App:
https://github.com/arafath65/gym-management-apps.git
```

A previously pushed Super Admin commit was `6d7a5ca` (`Improve device management cards and search`). Later License and Audit module changes happened after that point. Check each repository's current branch and `git status` before pushing; this document does not assume the later changes are already committed.

---

**End of master handover document.**
