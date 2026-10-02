## 0.1.0

- Provide Linux and macOS direct-node and isolate-worker APIs for Noosphere
  participants and embedded coordinators.
- Keep identity, client, room and coordinator persistence with host providers.
- Bind approval to immutable proposal bytes and preserve client storage ordering
  across worker replacement when the host reuses a provider instance.
- Reject overlapping lifecycle changes to one setup with `setup_busy`, and
  reject duplicate role starts before changing host providers.
- Expose public progress, completion, key and session replacement events.
- Include a desktop example and unit and native integration tests.
