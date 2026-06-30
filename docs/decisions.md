# Decisions

## 2026-06-29: Build A Local Review Packet Consumer Before Any Gateway

Context: after the tooling lane closed `context-pack-builder`, `eval-harness`,
`prompt-registry`, and `backend-service-template`, the next control question was
whether there was still a real integration gap inside `backend-challenges`.
Searches across the workspace showed no in-scope consumer that combined context
generation, readiness evidence, and canonical prompt materialization in one
command. The only explicit prompt consumer was in an out-of-scope ML repo.

Options considered:

- build `ai-engineering-gateway`
- stop and declare no gap
- build one small local packet consumer

Choice: build one small local packet consumer.

Why:

- it solves a proven in-workspace gap
- it is visible to a reviewer in under five minutes
- it keeps complexity local and file-based
- it proves real consumption of the published tooling assets

Rejected:

- `ai-engineering-gateway`: no concrete in-scope consumer currently needs
  hosted prompts, auth, routing, or persistence
- no-op: the workspace would still lack a reusable end-to-end operator flow

Verification evidence:

- workspace search for in-scope integrated consumers returned none
- `./bin/check`
- `ruby bin/review-packet-builder ../rails_doctor --output tmp/rails_doctor-packet`

## 2026-06-29: Shell Out To Sibling CLIs Instead Of Linking Tool Libraries

Context: the three upstream tools already exist as separate public repos with
their own contracts and release cadence.

Options considered:

- load their Ruby libraries directly
- copy logic into this repo
- shell out to their published CLIs

Choice: shell out to the sibling CLIs.

Why:

- preserves clear ownership boundaries
- respects each tool's public entrypoint
- keeps this repo small
- makes the executed commands explicit in the generated packet

Rejected:

- direct library linkage: tighter coupling across repos for little benefit
- copied logic: duplicates behavior that already has a canonical owner

Verification evidence:

- targeted tests using fixture CLIs under `test/fixtures`
- `./bin/check`

## 2026-06-30: Stamp Packets With Target And Tool Provenance

Context: the first integrated packet already carried the generated artifacts and
the exact shell commands used to build them, but it still made a reviewer infer
too much. A cheap model or human could see which CLIs ran, yet could not tell
at a glance which target revision and which upstream tool revisions produced the
packet.

Options considered:

- keep only the executed command list
- record provenance only inside the generated child artifacts
- surface target and tool provenance directly in `packet.md`

Choice: surface target and sibling-tool provenance directly in `packet.md`.

Why:

- it gives the consumer one top-level freshness summary
- it keeps packet trust tied to concrete repository state instead of only file
  timestamps
- it avoids forcing the reviewer to mine each child artifact before deciding
  whether regeneration is needed

Rejected:

- commands only: path visibility is weaker than commit visibility
- child artifacts only: the packet index should summarize trust, not only link
  to deeper evidence

Verification evidence:

- `bundle exec rake test`
- `ruby bin/review-packet-builder ../rails_doctor --ruby /Users/allanflavio/.asdf/installs/ruby/3.4.9/bin/ruby --output /tmp/rails_doctor-review-packet`
