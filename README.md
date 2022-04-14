# snippets
MacOS Remove all DS_Store (useful for enforcing list view)
```
sudo find / -name ".DS_Store"  -exec rm {} \;
```

Discard git changes
```
git stash save --keep-index --include-untracked && git stash drop
```
 This is text for a test comm it from vscode online using an iPad.
