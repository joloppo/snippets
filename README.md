# snippets

Remove github deployment environment (requires jq installed) env is environment name
```
env=
token=
repo=
user=

for id in $(curl -u $user:$token https://api.github.com/repos/$user/$repo/deployments\?environment\=$env | jq ".[].id"); do
    curl -X POST -u $user:$token -d '{"state":"inactive"}' -H 'accept: application/vnd.github.ant-man-preview+json' https://api.github.com/repos/$user/$repo/deployments/$id/statuses
    curl -X DELETE -u $user:$token https://api.github.com/repos/$user/$repo/deployments/$id
done
```

MacOS Remove all DS_Store (useful for enforcing list view)
```
sudo find / -name ".DS_Store"  -exec rm {} \;
```

Discard git changes
```
git stash save --keep-index --include-untracked && git stash drop
```
 This is text for a test comm it from vscode online using an iPad.
