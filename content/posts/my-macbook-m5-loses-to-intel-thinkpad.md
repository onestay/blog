+++
date = '2026-03-30T19:27:08+02:00'
draft = true
title = 'My M5 MacBook Air loses to a 4 year old Intel ThinkPad at git status'
tags = ["macOS", "linux", "performance"]
+++

I've recently purchased a MacBook Air M5, 512GB SSD and 24GB memory and was very excited to replace my old 11th gen Intel ThinkPad with it.
It's my first Apple Silicon machine and I'm really impressed by its performance.
Silent, fast builds, 20 YouTube tabs without as much as a single noise from the machine.

However *something* felt off when I opened my terminal.
Entering commands felt sluggish.
I use [starship](https://starship.rs/) for my prompt and it regularly warned me about this:

```
[WARN] - (starship::utils): Executing command "/opt/homebrew/bin/git" timed out.
```

Benchmarking the starship prompt showed `git_status` taking over 500ms -- on a repo with about 50 tracked files and 4 commits:

```bash
$ starship timings
 Here are the timings of modules in your prompt (>=1ms or output):
 git_status  -  507ms  -   ""
 nodejs      -   34ms  -   "via  v25.8.1 "
 directory   -    8ms  -   "budget "
 git_branch  -  <1ms  -   "on  main "
```

On my ThinkPad L14 running Linux the same starship prompt with the same config takes <1ms for `git_status`.
Something is very wrong here.

## Git config

I share my git config between machines via a dotfiles repo.
Looking through it I found that `core.excludesfile` was set to a path
in my home directory on my old ThinkPad, which obviously doesn't exist on my MacBook.

Benchmarking with the broken path vs without:

```bash
$ hyperfine --warmup 3 'git status'
Benchmark 1: git status
  Time (mean ± σ):      17.2 ms ±   1.5 ms    [User: 2.4 ms, System: 1.9 ms]
  Range (min … max):    15.1 ms …  23.2 ms    115 runs

# after fixing excludesfile:
$ hyperfine --warmup 3 'git status'
Benchmark 1: git status
  Time (mean ± σ):       8.5 ms ±   0.4 ms    [User: 2.2 ms, System: 1.5 ms]
  Range (min … max):     7.6 ms …   9.0 ms    272 runs
```

The spikes don't show up here, they mostly occurred when executing `git status` for the first time in some time,
or for the first time in a new terminal window.
But now 17ms down to 8.5ms and the spikes and timeouts were gone.
Interestingly, setting `core.excludesfile` to a non-existent path on Linux doesn't seem to cause any such issues.
I have no idea what macOS does differently here but it clearly doesn't handle it gracefully.

But starship still reported:

```bash
$ starship timings
 Here are the timings of modules in your prompt (>=1ms or output):
 nodejs      -  21ms  -   "via  v25.8.1 "
 git_status  -  21ms  -   "[!2✓] "
 directory   -   9ms  -   "budget "
```

21ms for `git_status` on a tiny repo.
How is this machine getting beaten by a 4-year-old ThinkPad?

## Fsmonitor overhead

I had `core.fsmonitor=true` set globally
which is great for large repos with thousands of files.
But for a tiny 50 file repo the overhead of the IPC calls seems to outweigh the benefits.

Here are all three configurations benchmarked:

```bash
# both issues present (fsmonitor + broken excludesfile):
❯ hyperfine --warmup 3 'git status'
Benchmark 1: git status
  Time (mean ± σ):      24.9 ms ±   1.5 ms    [User: 2.8 ms, System: 2.2 ms]
  Range (min … max):    21.6 ms …  28.6 ms    95 runs

# excludesfile fixed, fsmonitor still active:
❯ hyperfine --warmup 3 'git status'
Benchmark 1: git status
  Time (mean ± σ):       8.5 ms ±   0.4 ms    [User: 2.1 ms, System: 1.4 ms]
  Range (min … max):     7.6 ms …   9.0 ms    275 runs

# both fixed:
❯ hyperfine --warmup 3 'git status'
Benchmark 1: git status
  Time (mean ± σ):       3.4 ms ±   0.3 ms    [User: 1.9 ms, System: 1.3 ms]
  Range (min … max):     3.0 ms …   5.0 ms    480 runs
```

From 25ms down to 3.4ms -- a 7x improvement.
The fsmonitor IPC overhead alone costs more than just stat-ing 50 files directly.

What's interesting is that the 500ms+ timeouts and spikes only happened with *both* issues present.
The fsmonitor daemon combined with the broken excludesfile path
seems to create some kind of weird interaction on macOS
that neither issue causes on its own.

Funnily enough, I had accumulated **50 fsmonitor daemon processes**
even though I only had about 5 git repos cloned:

```
$ ps -ef | grep fsmonitor | wc -l
50
```

The lesson learned here: don't enable fsmonitor globally.
Enable it per-repo where it actually helps.

## So where does the remaining time go?

After both fixes, `git status` benchmarks at about 3.4ms on this MacBook.
On my ThinkPad, the same operation on the same repo takes about 1ms.
Still a 3.4x difference on vastly superior hardware.

To figure out where the time goes I ran `GIT_TRACE2_PERF=1 git status` on both machines
against the same repo with the same git version (2.53.0).

**Linux (ThinkPad L14, 11th gen Intel, btrfs):**

```
region_leave |  0.000954 |  0.000074 | index        | label:do_read_index
region_leave |  0.001049 |  0.000080 | index        | label:refresh
region_leave |  0.001202 |  0.000036 | status       | label:worktrees
region_leave |  0.001603 |  0.000398 | status       | label:index
region_leave |  0.001878 |  0.000269 | status       | label:untracked
region_leave |  0.002343 |  0.000095 | status       | label:print
atexit       |  0.002381 |           |              | code:0
```

**macOS (MacBook Air M5, APFS):**

```
region_leave |  0.002089 |  0.000097 | index        | label:do_read_index
region_leave |  0.002261 |  0.000154 | index        | label:refresh
region_leave |  0.002577 |  0.000063 | status       | label:worktrees
region_leave |  0.004172 |  0.001583 | status       | label:index
region_leave |  0.004586 |  0.000410 | status       | label:untracked
region_leave |  0.004843 |  0.000141 | status       | label:print
atexit       |  0.004862 |           |              | code:0
```

Side by side:

| Phase | Linux | macOS | Ratio |
|-------|------:|------:|------:|
| do_read_index | 0.07ms | 0.10ms | 1.4x |
| refresh (lstat all files) | 0.08ms | 0.15ms | 2x |
| worktrees | 0.04ms | 0.06ms | 1.6x |
| index (unpack_trees) | 0.40ms | 1.58ms | **4x** |
| untracked (read_directory) | 0.27ms | 0.41ms | 1.5x |
| print | 0.10ms | 0.14ms | 1.4x |
| **Total** | **2.4ms** | **4.9ms** | **2x** |

Every single phase is slower on macOS.
The biggest offender is `unpack_trees` at 4x slower.
These are all pure filesystem metadata operations.

## Is it APFS?

At this point I was suspicious of the filesystem itself.
APFS is a copy-on-write filesystem, similar to btrfs on Linux.
Both trade some metadata performance for features like snapshots and checksums.
But the ThinkPad runs btrfs and still beats APFS easily.

I ran a quick stat benchmark on three machines which create 1000 files, then stat them all:

```bash
mkdir -p /tmp/fstest && cd /tmp/fstest
for i in $(seq 1 1000); do touch "file_$i"; done
hyperfine --warmup 3 'stat /tmp/fstest/file_* > /dev/null 2>&1'
```

<!-- TODO: re-run with exact hyperfine output on all machines -->

| Machine | Time |
|---------|-----------|
| ThinkPad L14 (11th gen Intel) | ~400ms |
| MacBook Air M5  | ~800ms |
| My girlfriends MacBook Air M1 | ~1100ms |

APFS is roughly 2x slower than btrfs at metadata operations.
And btrfs is even considered a relatively slow filesystem on Linux.
ext4 might widen the gap further.

The M5 is faster than the M1 which suggests Apple has been improving APFS.
But it's still meaningfully slower at metadata lookups
than a "slow" Linux filesystem running on 4-year-old hardware.

After trying to see if someone else had done some research on this issue
I came across the great [blog post by Gregory Szorc from 2018](https://gregoryszorc.com/blog/2018/10/29/global-kernel-locks-in-apfs/).

It appears that APFS takes a global kernel lock on read-only operations like `readdir()`.
Apple improved this in Mojave but the fundamental design remains more lock-heavy than Linux filesystems.

## It's not just the filesystem

The filesystem part is not all of it.
macOS adds overhead that Linux doesn't on every single process execution:
Notarization checks for example can do [synchronous network activity on exec()](https://sigpipe.macromates.com/2020/macos-catalina-slow-by-design/).

I couldn't find too much in terms of benchmarks but the [OS primitives benchmark](https://www.bitsnbites.eu/benchmarking-os-primitives/) from Bits'n'Bites
puts process creation at 5-10x slower.
Now this benchmark is almost 10 years old and things most likely have changed but it might explain some differences.

For a tool like starship that spawns several subprocesses per prompt (git, node, etc.), this overhead can add up.
Each subprocess pays the macOS tax on spawn, and each git/node invocation pays it again on the filesystem operations.

Even comparing simple `--version` process invocations between my MacBook:
```bash
$ hyperfine --warmup 3 'node --version'
Benchmark 1: node --version
  Time (mean ± σ):      11.5 ms ±   0.7 ms    [User: 8.8 ms, System: 2.3 ms]
  Range (min … max):    10.5 ms …  14.5 ms    212 runs

$ hyperfine --warmup 3 'python3 --version'
Benchmark 1: python3 --version
  Time (mean ± σ):       7.6 ms ±   0.7 ms    [User: 4.2 ms, System: 2.2 ms]
  Range (min … max):     6.5 ms …  10.7 ms    291 runs
```

and my ThinkPad:

```bash
$ hyperfine --warmup 3 'node --version'
Benchmark 1: node --version
  Time (mean ± σ):       5.0 ms ±   0.5 ms    [User: 2.4 ms, System: 2.4 ms]
  Range (min … max):     4.0 ms …   6.9 ms    487 runs
 
$ hyperfine --warmup 3 'python3 --version'
Benchmark 1: python3 --version
  Time (mean ± σ):       1.5 ms ±   0.3 ms    [User: 0.6 ms, System: 1.0 ms]
  Range (min … max):     1.0 ms …   3.2 ms    1056 runs
```

shows a clear "winner".

## The irony

This is genuinely one of the best laptops I've ever used.
Builds are fast, the battery lasts forever, and due to having no fans it's completely quiet.
It is better than my ThinkPad at everything,
except the thing I do most of the time: using the terminal.

Apple doesn't optimize their OS for the "spawn many short-lived processes that stat a bunch of files"
workload that terminal workflows use.
Fair enough, but it means that one of the fastest consumer laptops you can buy today
loses to a 4-year-old Intel ThinkPad at `git status`...
