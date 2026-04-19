# Publishing Addons to ESOUI

This document describes how to package and publish first-party addons from this repository to ESOUI.

## Package the Addon

From the repository root, run:

```bash
scripts/package-addons.sh
```

For the current repository, this creates:

```text
dist/MiniMap-1.0.0.zip
```

The archive is expected to contain the addon folder at its root:

```text
MiniMap/
  MiniMap.txt
  MiniMap.lua
  ...
```

Do not upload an archive that contains an extra parent folder such as `AddOns/` or `MiniMap-1.0.0/`.

## First Upload

The first upload must be done through the ESOUI website.

1. Sign in or create an account at <https://www.esoui.com/>.
2. Build the addon zip with `scripts/package-addons.sh`.
3. Prepare one or more in-game screenshots.
4. Go to the ESOUI downloads area and choose the matching addon category.
5. Use the upload action to create a new addon entry.
6. Fill in the addon title, description, version, dependencies, and changelog.
7. Upload the zip from `dist/`.
8. Submit the addon for review.

ESOUI moderates new addons. Updates that replace the downloadable file may also enter the review queue.

## MiniMap Metadata

For MiniMap, the manifest is:

```text
MiniMap/MiniMap.txt
```

Before publishing, verify:

- `## Version:` matches the public release version.
- `## AddOnVersion:` is incremented when appropriate.
- `## APIVersion:` matches the current ESO API version supported by the addon.
- `## DependsOn:` lists required dependencies.

MiniMap currently depends on:

```text
LibAddonMenu-2.0
```

List `LibAddonMenu-2.0` as a dependency on ESOUI. Do not bundle third-party libraries in the MiniMap zip unless that is an intentional release decision.

## Upload Rules

Use a clean `.zip` archive.

Do not include:

- executable files;
- nested zip archives;
- local temporary files;
- generated development output;
- unrelated third-party addons;
- an extra top-level parent directory.

Credit any third-party code, artwork, or assets that are included in the addon package.

## Updating an Existing Addon

After the addon exists on ESOUI, updates can be uploaded through the website or through the ESOUI API.

Generate an API token while signed in:

```text
https://www.esoui.com/downloads/filecpl.php?action=apitokens
```

Keep the token private. A shell environment variable is a reasonable local workflow:

```bash
export ESOUI_TOKEN="your-token"
```

Use ESOUI's test endpoint before doing the real update:

```bash
curl -H "x-api-token: $ESOUI_TOKEN" \
  -F "id=ADDON_ID" \
  -F "version=1.0.1" \
  -F "updatefile=@dist/MiniMap-1.0.1.zip" \
  https://api.esoui.com/addons/updatetest
```

If the test succeeds, upload the real update:

```bash
curl -H "x-api-token: $ESOUI_TOKEN" \
  -F "id=ADDON_ID" \
  -F "version=1.0.1" \
  -F "updatefile=@dist/MiniMap-1.0.1.zip" \
  https://api.esoui.com/addons/update
```

Replace `ADDON_ID` with the numeric ESOUI addon ID and update the version and zip path for the release.

## Release Checklist

1. Update `## Version:` in the addon manifest.
2. Update `## AddOnVersion:` if needed.
3. Update the changelog or release notes.
4. Run `scripts/package-addons.sh`.
5. Inspect the zip contents.
6. Test the packaged addon in ESO.
7. Upload the zip to ESOUI.

