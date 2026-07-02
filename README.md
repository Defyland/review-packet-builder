# Review Packet Builder

`review-packet-builder` is the smallest integrated consumer for the current
`backend-challenges` tooling stack.

It takes one target repository and produces one local packet directory with:

- a generated context pack from `context-pack-builder`
- a readiness report from `eval-harness`
- a materialized task prompt from `prompt-registry`
- an index file that tells a human or cheap model how to use the packet and
  which target/tool revisions generated it

This asset exists because the workspace already had the building blocks, but no
single in-scope command that made them usable together end to end.

## Why This Exists

The workspace already has four ready/public tooling assets:

- `context-pack-builder`
- `eval-harness`
- `prompt-registry`
- `backend-service-template`

What was still missing was the first real local consumer that turns the first
three into one review-ready artifact. Without that, cheap-model operation still
depends on manual command choreography and ad hoc prompt assembly.

`review-packet-builder` closes that integration gap without opening
`ai-engineering-gateway` prematurely.

## What It Produces

For one target repo, the builder writes:

- `context-pack.md`
- `readiness.md`
- `readiness.json`
- `prompt.md`
- `packet.md`

The output is local and deterministic. There is no remote service, queue,
database, or hosted prompt layer.
`packet.md` also records target-repo and sibling-tool provenance so a reviewer
can tell whether the packet is fresh enough to trust.

## Five-Minute Evaluation

Run the repository contract:

```sh
./bin/check
```

Build a real packet for an in-scope repo:

```sh
ruby bin/review-packet-builder ../rails_doctor --output tmp/rails_doctor-packet
```

Build a real packet for a Python research repo:

```sh
ruby bin/review-packet-builder ../brainbench --output tmp/brainbench-packet
```

Inspect the generated index:

```sh
sed -n '1,120p' tmp/rails_doctor-packet/packet.md
```

Inspect the materialized prompt:

```sh
sed -n '1,120p' tmp/rails_doctor-packet/prompt.md
```

Inspect the Python packet index:

```sh
sed -n '1,120p' tmp/brainbench-packet/packet.md
```

## CLI

Basic usage:

```sh
ruby bin/review-packet-builder ../rails_doctor
```

Choose a different prompt:

```sh
ruby bin/review-packet-builder ../rails_doctor \
  --prompt review \
  --output tmp/rails_doctor-review-packet
```

Override prompt values:

```sh
ruby bin/review-packet-builder ../rails_doctor \
  --task-context "Review the latest packaged-gem release surface." \
  --constraints "Find real regressions first." \
  --verification "Read the packet, then rerun the concrete repo contract."
```

Use custom tool roots:

```sh
ruby bin/review-packet-builder test/fixtures/demo-repo \
  --context-pack-builder-root test/fixtures/context-pack-builder \
  --eval-harness-root test/fixtures/eval-harness \
  --prompt-registry-root test/fixtures/prompt-registry
```

## Boundary

This repo intentionally does not:

- host prompts remotely
- route model traffic
- store packet history
- manage policy, auth, or spend controls

Those concerns still belong to a future gateway only if a real consumer forces
that complexity.

## Verification Surface

`bin/check` proves:

- tests pass
- the CLI can build a packet end to end
- the packet contains the expected artifact set and provenance summary

For a workspace-level smoke path, use the real `rails_doctor` example above.

## Architecture

The tool has three responsibilities:

- shell out to the published sibling CLIs
- collect their outputs into one directory
- render a concise operator index

More detail lives in [docs/architecture.md](./docs/architecture.md).

## License

MIT. See [LICENSE.txt](./LICENSE.txt).
