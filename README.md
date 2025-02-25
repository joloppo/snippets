# snippets

### Remove github deployment environment (requires jq installed) env is environment name
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

### MacOS Remove all DS_Store (useful for enforcing list view)
```
sudo find / -name ".DS_Store"  -exec rm {} \;
```

### Discard git changes
```
git stash save --keep-index --include-untracked && git stash drop
```

### Kill postgres connections
```
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'mydb' -- ← change this to your DB
  AND pid <> pg_backend_pid();
```

### Print all of a dataframe
```
with pd.option_context('display.max_rows', None, 'display.max_columns', None):
    print(df)
```

### Get DBeaver credentials
```
openssl aes-128-cbc -d -K babb4a9f774ab853c96c2d653dfe544a -iv 00000000000000000000000000000000 -in "${HOME}/Library/DBeaverData/workspace6/General/.dbeaver/.credentials-config.json.bak" | dd bs=1 skip=16 2>/dev/null
```


### Git delete tracking branches not on remote
```
git remote prune origin
```

### Git delete local branches not on remote
```
git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D
```

### Installing pytables Macos [github1](https://github.com/freqtrade/freqtrade/issues/4162#issuecomment-890377818) --- [stackoverflow](https://stackoverflow.com/questions/73029883/could-not-find-hdf5-installation-for-pytables-on-m1-mac)

```
export HDF5_DIR=/opt/homebrew/opt/hdf5
```

### Kill process running or port 8000 MacOS
```
kill -9 $(lsof -ti:8000)
```

### When psycopg wont install python stuff. install some libpq shit or psycopg binary idk
```
sudo apt install libpq-dev
```

### Pyzmq on M1 - use this version (needed for jupyter notebook (?))
```
'pyzmq==25.1.0'
```

### Print entire pandas df dataframe
```
with pd.option_context('display.max_rows', None, 'display.max_columns', None, 'display.precision', 3,):
```

```
import polars as pl
def full_print(df):
    with pl.Config(fmt_str_lengths=1000, tbl_width_chars=1000, fmt_table_cell_list_len=100, set_tbl_rows=100):
        display(df)
```

### Get current dir subdir/file sizes, sorted
```
du -h -d 1 | sort -h
```



### Postgres stuffs
```sql
SELECT relname, n_live_tup FROM pg_stat_user_tables; -- Table & counts

SELECT
   relname  as table_name,
   pg_size_pretty(pg_total_relation_size(relid)) As "Total Size",
   pg_size_pretty(pg_indexes_size(relid)) as "Index Size",
   pg_size_pretty(pg_relation_size(relid)) as "Actual Size"
   FROM pg_catalog.pg_statio_user_tables 
ORDER BY pg_total_relation_size(relid) DESC;



SELECT 
    attname AS column_name,
    avg_width AS average_size_in_bytes
FROM 
    pg_stats
WHERE 
    schemaname = 'public'
    AND tablename = 'my_table';

select pg_size_pretty(pg_database_size('my_db'));
```
