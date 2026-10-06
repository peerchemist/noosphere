# Flutter facade and isolates

[Architecture overview](../architecture.md)

`NoosphereNode` composes participant/server roles in the caller's isolate.
`NoosphereWorker` runs the same cores in a long-lived isolate and exposes a
smaller DTO-based API suitable for Flutter UI code.

## Direct node versus worker

Direct startup starts the server before the client, cleans up partial failure
and closes client before server. Combined roles still require an explicit
trusted coordinator pin. Direct callers handle replacement client sessions and
run synchronous cryptographic work on their own isolate.

When the pin and group match a coordinator in the same process, the client uses
`LocalCoordinatorApi` instead of opening a second Iroh endpoint and loopback
QUIC connection. Login, sessions, events and the server's serialized group lane
remain unchanged. The embedded server still uses Iroh for remote participants.

The worker owns endpoints, protocol objects and native Frosty values. The host
owns UI state, provider callbacks, database objects and secure-key policy.
Callbacks and native handles never cross the port; encoded configuration,
storage values and required key bytes do. The worker is a scheduling boundary,
not a keystore or OS security boundary.

## Initialization and messages

The root isolate prepares Flutter bindings; each isolate initializes native
Coinlib, Iroh and Frosty bindings for itself. macOS loading keeps Iroh/Frosty
bridge symbols separated.

Worker envelopes distinguish commands, replies, provider calls and public
events. Generation IDs reject stale messages; separate request IDs correlate
commands and provider operations. Defaults are:

| Limit | Default |
| --- | ---: |
| Approximate message size | 8 MiB |
| Outstanding commands/provider calls | 64 |
| Startup/provider timeout | 30 s |
| Shutdown stage timeout | 5 s |

There is no blanket timeout for every command. Oversized events become failure
events; oversized replies fail their command.

## Setups and commands

One worker can host several named setups, each with serialized signer/server
lifecycle. `startSetup` can add a missing role. Overlapping lifecycle actions
on one setup fail with `setup_busy`; separate setups still share one isolate
and event loop. A matching signer/server pair selects the same local coordinator
path automatically.

The public API starts/stops roles, locks a signer, reads snapshots, updates
address hints, switches coordinators, submits DKG/signing requests and
accepts/rejects exact proposal bytes. Recovery-share and room-management APIs
are not exposed through the worker.

Storage and key calls return to the host through correlated adapters and
provider-instance FIFOs. Key requests include participant and `KeyPurpose`.
Provider timeouts do not cancel underlying storage transactions; see
[state and persistence](state-and-persistence.md).

## Sessions and shutdown

For every client session, the worker emits its snapshot before later events.
On reconnect it detaches the old client, installs the replacement, emits its
snapshot and then a replacement event; stale callbacks are discarded.

Graceful close stops commands, drains accepted work, closes setups in reverse
order and waits for isolate exit. Forced or unexpected termination marks
in-process native restart unsafe because killing Dart cannot prove native tasks
stopped; restart the application process instead.

Lifecycle observers attempt bounded close only on terminal `detached`, not on
ordinary `inactive`. Applications should still await explicit shutdown.

A start result can exceed the message limit after roles have successfully
started; providers remain reserved until explicit stop. Similarly, serving or
cleanup failure keeps role resources reserved for cleanup retry. A false health
flag is not permission to rebind providers.
