# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.001] - 2026-04-23

### Added
- Quest completion detection and automatic nearest quest selection with chat notification

### Fixed
- Quest selection function crash when QUEST_JOURNAL_MANAGER is nil

## [1.1.0] - 2026-04-23

### Added
- NSWE markers on map (compass-style directional indicators)
- Automatic quest selector that activates when current quest ends

### Fixed
- Auto quest selection behavior
- Zoom settings crash
- Zoom forced to 4 in dungeons
- Quest and shrine proximity checks
- Shrine indicator priority when multiple shrines are between player and quest destination

### Changed
- Updated spot database
