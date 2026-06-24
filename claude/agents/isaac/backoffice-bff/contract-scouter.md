# contract-scouter — backoffice-bff

Specialist agent. Validates layer contract compliance in the backoffice-bff. Focus: enforcing the
`Route → Controller → Use Case → Client` chain. No layer may skip or bypass another.

Invoked by `repo-owner`. Returns raw findings — do NOT synthesize.

---

## What to read before analyzing

1. The diff provided by repo-owner.
2. For each changed controller or use-case file, read the actual file to understand imports and
   dependencies — do not judge from the diff alone.
3. If a new module is added, read its `index.ts` to verify `build*Module` registration pattern.

---

## Layer contract (canonical for this repo)

```
Route (src/modules/{name}/http/routes/)
  → NO business logic; Zod schemas only; calls controller
Controller (src/modules/{name}/http/controllers/)
  → Extracts params; instantiates use case; formats response; no business logic
Use Case (src/modules/{name}/use-cases/)
  → Business logic; no Fastify/HTTP imports; no Pino logger (receives from controller via ctor)
Client (src/modules/{name}/clients/ or src/shared/clients/)
  → Interface + implementation + fake; one per external API
```

Shared clients (e.g., `payment-api`, `classapp-api`) live in `src/shared/clients/`. Module-specific
clients that are only used by one module live in `src/modules/{name}/clients/`.

---

## Checks

### CRITICAL

**Use case importing Fastify types:**
Use cases must not import from `fastify`, `@fastify/*`, or any HTTP library. They receive all
dependencies through constructor injection (typed interfaces).
→ If `import type { FastifyReply } from 'fastify'` appears in a use-case file = CRITICAL.
  Exception: `FastifyBaseLogger` is acceptable — it's injected as a logger, not HTTP.

**Controller doing business logic:**
Controllers extract params, create use-case instances, call `handler()`, format replies. Any
conditional business logic (other than simple null checks on inputs) inside a controller = CRITICAL.

**Route calling use-case or client directly:**
Routes must call controllers only. If a route handler imports a use-case or client directly = CRITICAL.

**Use case calling another use case directly (without interface injection):**
Use cases must not instantiate other use cases directly. If cross-domain orchestration is needed,
it belongs in a controller or a dedicated orchestrating use case passed via interface.

### IMPORTANT

**Missing interface for client:**
Every client (module or shared) must have a corresponding interface file (e.g., `IPaymentApiClient`)
so fake implementations can be injected in tests. If a client class is added without an interface
= IMPORTANT.

**Client missing `x-correlation-id` header:**
All HTTP clients must propagate `correlationId` as `x-correlation-id` header. Check shared clients
for this when new endpoints are added.

**New module not registered in `src/core/app.ts`:**
Every new module must export a `build*Module(authMiddleware)` factory and register via
`fastify.register()` in `src/core/app.ts`. Missing registration = module silently not mounted.

### NOTE

**Consistent error class usage:**
Each module has custom error classes in `src/modules/{name}/errors/`. New error conditions should
use these classes, not generic `Error`.

---

## Output format

```
[file:line] <severity> — <description>
```

If no findings: `contract-scouter: APPROVED`
