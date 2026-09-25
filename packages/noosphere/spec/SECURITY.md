# Security model

The Noosphere protocol assumes that participants obtain the coordinator's
identity through an independently trusted channel. An address hint does not
establish that identity. The reference Iroh transport authenticates the pinned
endpoint but does not replace application-level validation, durable nonce
state, explicit user consent, or recovery after an unknown mutation outcome.
