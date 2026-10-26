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

The user supplied `ziju-max` as the sole allowed account identity and authorized
checking the active GitHub CLI identity for the repository-local author setup.
Only the account ID needed to form that account's ID-based noreply address was
read; no other account, historical identity, credentials, or global Git author
configuration was inspected. The local repository uses that identity, has no
remote configured, and has not been pushed or otherwise accessed remotely.
