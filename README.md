# Redash-to-Git

## Setup

```bash
$ bundle
```

## Running

```bash
$ bundle exec r2g.rb -u https://app.redash.io/<org> -k REDASH_API_KEY [-o OUTPUT_DIR]
```

You can optionally set `REDASH_API_KEY` as an environment variable instead of a command line option above.

## Ignore List (`.r2gignore`)

You can specify any files in a file called `.r2gignore` and place it in your home directory. Any files matching that match will be ignored.
