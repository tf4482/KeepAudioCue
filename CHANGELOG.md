# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Shared settings component updated; no visible change

## [0.2.0] - 2026-11-24

### Added

- "Per character" checkbox and `/kac character on|off` to save the settings per character.
- `/kac test`, `/kac reset`, and `/kac debug on|off` commands.

### Changed

- Updated shared components; saved account settings stay as they are.

### Fixed

- Skip Cooldown Manager hooks and fields this client lacks instead of failing during setup.

## [0.1.0] - 2026-11-22

### Added

- Hide each Cooldown Manager window while its sound alerts keep playing.
- Warnings when Edit Mode visibility or a disabled Cooldown Manager silences alerts.
- Settings page, addon compartment entry, and `/kac` chat commands.
