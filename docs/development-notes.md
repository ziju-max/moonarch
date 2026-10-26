# Development notes

MoonArch was implemented from the approved design in this repository. The
human participant selected the project direction and approved its scope,
architecture, rule semantics, and acceptance criteria. An AI coding assistant
contributed implementation, tests, examples, and documentation. This note is
kept so that any later contest disclosure can accurately describe that work.

Before presenting or submitting MoonArch, the participant should be able to
explain and demonstrate:

- why the input adapter delegates package discovery to `moon tree`;
- how normal, test, and whitebox-test paths differ;
- why BFS produces a shortest deterministic witness;
- the exact behavior of each rule, exception expiry, and baseline fingerprint;
- what each report status and CLI exit code means;
- which local checks ran and which platform or remote checks did not run.

The local author identity and commit history must be established by the
participant before any commit is created. No GitHub account or remote was
inspected or used during implementation.
