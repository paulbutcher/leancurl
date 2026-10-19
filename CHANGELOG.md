# Changelog

## [0.3.2] - 2026-10-19

* Chore: bump dependencies

## [0.3.1] - 2026-08-29

* The build now treats warnings as errors
* A response body large enough to reach the shim in several pieces is now covered by the tests

## [0.3.0] - 2026-08-20

Switch to the module system.

## [0.2.1] - 2026-08-16

* libcurl's global initialisation now runs from `pthread_once` in the shim rather than a Lean `initialize` block
* The `Lean.Linter.Extra` linters are enabled, and the test library is a default target

## [0.2.0] - 2026-08-16

* Tests moved into a separate `test` package, so nothing they depend on reaches a downstream consumer
* Property and theorem tests covering header parsing and the method-to-verb mapping

## [0.1.0] - 2026-08-02

Initial release.
