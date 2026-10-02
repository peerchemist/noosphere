## 0.1.0

- Preserve host providers when startup succeeds but its snapshot exceeds the
  worker message limit; report `start_result_too_large` with a stop/retry path.
- Serialize identity operations without caching failed restore futures.
- Expose embedded server completion and report failed serving loops through
  worker health events and snapshots.
- Document the coordinated preview compatibility policy and native ownership
  boundary; pin Frosty to the tested version.

- Move YAML configuration parsing to the standalone server CLI. Remove shared
  map/YAML conversion APIs and YAML dependencies from the domain and client.

- Provide Linux and macOS direct-node and isolate-worker APIs for Noosphere
  participants and embedded coordinators.
- Keep identity, client, room and coordinator persistence with host providers.
- Bind approval to immutable proposal bytes and preserve client storage ordering
  across worker replacement when the host reuses a provider instance.
- Reject overlapping lifecycle changes to one setup with `setup_busy`, and
  reject duplicate role starts before changing host providers.
- Expose public progress, completion, key and session replacement events.
- Include a desktop example and unit and native integration tests.
