{ ... }:

{
  # Git configuration shared with the macosx repo so both machines behave the
  # same. This writes the global config (~/.config/git/config); a repo-local
  # .git/config still overrides these values where one exists.
  programs.git = {
    enable = true;
    settings = {
      user.name = "st1vc3";
      # GitHub noreply address: the account has email privacy on, and GitHub
      # rejects pushes whose commits contain the real address (GH007).
      user.email = "304027875+st1vc3@users.noreply.github.com";
      core.editor = "nvim";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;   # first `git push` just works, no -u dance
      pull.rebase = true;            # rebase instead of merge commits on pull
      fetch.prune = true;            # drop remote-tracking refs deleted upstream
      rebase.autoStash = true;       # pull --rebase works with a dirty tree
      diff.colorMoved = "default";   # moved lines colored differently from add/delete
      # Repos cloned over https still push over ssh - matches how this
      # machine authenticates to GitHub (no https credential helper set up).
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
