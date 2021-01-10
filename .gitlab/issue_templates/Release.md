/label ~backstage
/label ~"wf::backlog"
/label ~"area::release/packaging"
/label ~nuix

## Before

- [ ] Update the changelog
  - Manually, or use: reductech/pwsh/New-Changelog>
  - To include all issues from the last release tag to _HEAD_:
    `New-Changelog.ps1 -ProjectId 22513789 -ReleaseVersion <insert version>`
- [ ] Update the readme / documentation with any new changes

## Create Release

- [ ] Go to Repository > Tags > New Tag
  - Tag name: v0.1.0
  - _Message_ and _Release Notes_ should be the same: brief description of the release
    and any major (especially breaking) changes, and a link to the `changelog.md`.
