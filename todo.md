# Desktop feature checklist

Work items pulled from the freeform `todo`, rephrased and tracked here. Each box
is checked once the feature is implemented, deployed, and tested.

- [x] **Clipboard history with image support & quick-look** - Extend the
  launcher's clipboard (`cli`) mode to handle images. Highlighting an image
  entry pops up a quick-look preview at a proper size; the preview closes as
  soon as another entry is highlighted. Also fix the clipboard list so no entry
  is preselected on open (match the app list).
- [ ] **Workspaces widget on the status bar** - Add a pill on the far-left of
  the bar, matching the right-hand notification button in size and shape. It
  shows only the occupied workspaces (one indicator per workspace that has
  windows), and clicking one switches to that workspace.
- [ ] **USB auto-mount** - Automatically mount removable drives (USB sticks and
  similar) when they are plugged in.
- [x] **SSH launcher mode** - Typing `ssh` in the launcher switches it into an
  SSH mode; the host you then type is opened as an SSH session.
- [x] **Nix package search mode** - Typing `nsearch` switches the launcher into
  a Nix package search mode that queries nixpkgs and lists the matches.
- [x] **YouTube search** - `yt <query>` opens the default browser on YouTube
  search results for the query.
- [x] **Google search** - `ggl <query>` opens the default browser on Google
  search results for the query.
