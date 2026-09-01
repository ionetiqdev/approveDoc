# Environments

## Environment URLs

| Environment | URL | Branch |
|---|---|---|
| Development (ionetiq.dev) | `https://ionetiq.dev/approvedoc/dev/` | `dev` |
| Production (ionetiq.dev) | `https://ionetiq.dev/approvedoc/` | `main` |
| Development (vanity) | `https://approvedoc.app/dev/` | `dev` |
| Production (vanity) | `https://approvedoc.app/` | `main` |

`approvedoc.app` is a DNS alias pointing to the same server and folder as `ionetiq.dev/approvedoc`. No separate deployment needed.

## Supabase project

| Setting | Value |
|---|---|
| Project ID | `nkwpqboslnbeifyaegos` |
| Region | EU West (Ireland) |
| Organisation | gardenSOL (`0b116913-5b27-4c19-8eb9-bf5c4787e780`) |

## localStorage isolation

Each environment has completely isolated localStorage keys:

```
app_accent:ionetiq.dev/approvedoc/dev/      ← dev (ionetiq.dev)
app_accent:ionetiq.dev/approvedoc/          ← production (ionetiq.dev)
app_accent:approvedoc.app/dev/              ← dev (approvedoc.app)
app_accent:approvedoc.app/                  ← production (approvedoc.app)
```

See [localStorage Isolation](../architecture/localstorage.md).
