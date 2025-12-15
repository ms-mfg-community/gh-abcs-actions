# 9 - Caching & Performance Optimization
In this lab you will learn how to implement dependency caching in GitHub Actions workflows to speed up CI/CD pipelines.
> Duration: 15-20 minutes

References:
- [Caching dependencies to speed up workflows](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows)
- [actions/cache Repository](https://github.com/actions/cache)
- [Cache Action on Marketplace](https://github.com/marketplace/actions/cache)

## 9.1 Basic dependency caching

Caching stores files between workflow runs to avoid re-downloading or rebuilding unchanged dependencies. This is different from **artifacts**, which share files between jobs in a single workflow run or persist build outputs for download.

| Feature | Cache | Artifact |
|---------|-------|----------|
| Purpose | Reuse dependencies across runs | Share files between jobs or store outputs |
| Lifetime | Up to 7 days (unused) | 90 days default |
| Use case | `node_modules`, `~/.npm`, `~/.m2` | Build outputs, test reports |

The `actions/cache@v4` action requires two inputs:
- **path**: The file or directory to cache (e.g., `~/.npm`)
- **key**: A unique identifier for this cache (should change when dependencies change)

1. Open or create a workflow file `.github/workflows/ci-caching.yml`
2. Add the following workflow with basic caching:
```yaml
name: 09-1. CI with Caching

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    name: Build with Cache
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Cache npm dependencies
        uses: actions/cache@v4
        id: npm-cache
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run build
        run: npm run build --if-present
```
3. Commit the file to your repository
4. Go to **Actions** and run the workflow
5. Run it a second time and observe the cache being restored (look for "Cache restored successfully")

The `hashFiles('**/package-lock.json')` function creates a hash of your lockfile. When dependencies change, the lockfile changes, creating a new cache key.

## 9.2 Using restore-keys for fallbacks

When the exact cache key doesn't match, `restore-keys` provides fallback options. The cache action searches in order:
1. **Exact match** on `key`
2. **Prefix match** on each `restore-keys` entry (top to bottom)

This is useful when your lockfile changes but you still want to restore a partial cache rather than starting fresh.

The pattern uses decreasing specificity—more specific keys first, broader fallbacks last:

```yaml
key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
restore-keys: |
  ${{ runner.os }}-node-
  ${{ runner.os }}-
```

1. Update your `.github/workflows/ci-caching.yml` cache step to add restore-keys:
```yaml
      - name: Cache npm dependencies
        uses: actions/cache@v4
        id: npm-cache
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-npm-
            ${{ runner.os }}-
```
2. Commit the changes
3. Modify your `package.json` to add a new dependency (e.g., `npm install lodash`)
4. Commit and push to trigger the workflow
5. Observe in the logs: the exact key won't match, but a restore-key prefix will match the previous cache

When a restore-key matches, the cache is restored but the step output `cache-hit` returns `false` (partial match). A new cache will be saved with the exact key at the end of the job.

## 9.3 Caching in matrix builds

Matrix builds run the same job with different configurations (OS, language version, etc.). Each matrix combination needs its own cache to avoid conflicts—a cache created on `ubuntu-latest` won't work on `windows-latest`.

Include matrix variables in your cache key to create separate caches per combination:

```yaml
key: ${{ runner.os }}-node-${{ matrix.node-version }}-${{ hashFiles('**/package-lock.json') }}
```

Common cache paths differ by operating system:

| Package Manager | Linux/macOS | Windows |
|-----------------|-------------|---------|
| npm | `~/.npm` | `~\AppData\npm-cache` |
| yarn | `~/.cache/yarn` | `~\AppData\Local\Yarn\Cache` |
| pip | `~/.cache/pip` | `~\AppData\Local\pip\Cache` |

1. Replace your workflow with this matrix build example:
```yaml
name: 09-1. CI with Caching

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    name: Build (Node ${{ matrix.node-version }} on ${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        node-version: [18, 20]

    steps:
      - uses: actions/checkout@v4

      - name: Cache npm dependencies
        uses: actions/cache@v4
        id: npm-cache
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ matrix.node-version }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-${{ matrix.node-version }}-
            ${{ runner.os }}-node-
            ${{ runner.os }}-

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        run: npm ci

      - name: Run build
        run: npm run build --if-present
```
2. Commit and push the changes
3. Go to **Actions** and observe 4 parallel jobs (2 OS × 2 Node versions)
4. Check the cache step in each job—each creates/restores its own cache with a unique key

## 9.4 Conditional installation on cache hit

The cache action provides a `cache-hit` output that indicates whether an exact key match was found:
- `'true'` — Exact cache key matched (full cache restore)
- `'false'` — Restore-key prefix matched (partial restore)
- Empty — No cache found

You can use this output to skip dependency installation when the cache is fully restored, saving additional time.

The pattern references the step by its `id`:
```yaml
if: steps.npm-cache.outputs.cache-hit != 'true'
```

1. Update your workflow to add a conditional install step:
```yaml
      - name: Cache npm dependencies
        uses: actions/cache@v4
        id: npm-cache
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ matrix.node-version }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-${{ matrix.node-version }}-
            ${{ runner.os }}-node-
            ${{ runner.os }}-

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        if: steps.npm-cache.outputs.cache-hit != 'true'
        run: npm ci
```
2. Commit and push the changes
3. Run the workflow twice
4. On the second run, observe that "Install dependencies" is **skipped** when the cache hits exactly
5. Check the step output: `cache-hit` will show `true` for exact matches

**Note**: This optimization works best when caching `node_modules` directly rather than `~/.npm`. With `~/.npm`, you're caching the npm download cache, so `npm ci` still needs to copy files to `node_modules`. For maximum speed, consider caching `node_modules` itself (but be aware this is less portable across Node versions).

## 9.5 Cache management

Understanding how GitHub manages caches helps you design effective caching strategies.

**Cache Scope and Branch Access**

Caches are scoped by branch with specific access rules:
- **Default branch (main)**: Can only access caches created on the default branch
- **Feature branches**: Can access caches from the same branch AND the default branch
- **Pull requests**: Can access caches from the head branch, base branch, AND default branch

This means caches created on `main` are available to all feature branches, making them ideal for seeding initial caches.

**Storage Limits and Eviction**

| Limit | Value |
|-------|-------|
| Free storage per repository | 10 GB |
| Individual cache size | No hard limit |
| Cache retention (unused) | 7 days |
| Eviction policy | Least Recently Used (LRU) |

When the repository exceeds 10 GB:
1. GitHub evicts the least recently accessed caches first
2. Caches not accessed for 7+ days are also eligible for eviction
3. Caches from the current workflow run are protected

**Viewing Cache Entries**

1. Go to your repository on GitHub
2. Click **Actions** in the top navigation
3. Click **Caches** in the left sidebar under "Management"
4. View all cache entries with their keys, sizes, and last accessed times
5. You can manually delete caches from this interface if needed

**Best Practices**

- Use specific cache keys to avoid unnecessary cache misses
- Include `runner.os` in keys for cross-platform workflows
- Use `hashFiles()` on lockfiles for automatic invalidation
- Keep cache sizes reasonable—large caches take longer to restore
- Monitor cache usage in the Actions UI to identify optimization opportunities

**Advanced: Programmatic Cache Management**

For automation, you can use the GitHub REST API or `gh` CLI to manage caches:
```bash
# List caches for a repository
gh cache list

# Delete a specific cache
gh cache delete <cache-id>
```

## 9.6 Final
<details>
  <summary>ci-caching.yml</summary>

```yaml
name: 09-1. CI with Caching

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    name: Build (Node ${{ matrix.node-version }} on ${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        node-version: [18, 20]

    steps:
      - uses: actions/checkout@v4

      - name: Cache npm dependencies
        uses: actions/cache@v4
        id: npm-cache
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ matrix.node-version }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-${{ matrix.node-version }}-
            ${{ runner.os }}-node-
            ${{ runner.os }}-

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        if: steps.npm-cache.outputs.cache-hit != 'true'
        run: npm ci

      - name: Run build
        run: npm run build --if-present

      - name: Run tests
        run: npm test --if-present
```
</details>
