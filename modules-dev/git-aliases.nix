{
  # mixed: unstages the changes but keeps them in your working directory
  # other options: soft, hard
  undoco = "reset HEAD~1 --mixed"; # undo last commit but keep changes staged
  editco = "commit --amend"; # edit the last commit message
  prune-remote = "fetch --prune"; # remove remote branches not on server
}