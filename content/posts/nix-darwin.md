+++
date = '2026-05-09T18:52:43+02:00'
draft = true
title = 'Understanding Nix from first principles'
tags = ['nix', 'nix-darwin']
+++

I had never actually used Nix, but have always wanted to play around with it.
Looking into it I was immediately overwhelmed.
In the end I followed a few guides, wrote some files and ran some commands and it worked.
This however did not satisfy me and I wanted to know what actually happens, when I run nix or nix-darwin commands.
In this post I wanted to share my journey a bit and explain nix from the bottom up as I understand it now.

## Derivations: nix's core principle

What initially helped me better understand Nix, flakes, home-manager, nix-darwin and nixpkgs was to understand them each in isolation.

Nix in itself does not really concern itself with OS configuration or even being a package manager.
Nix itself is a functional language, a set of CLI tools and a daemon.

The language is best described by the introductory paragraph of the [Nix language basics tutorial](https://nix.dev/tutorials/nix-language.html).

> The Nix language is designed for conveniently creating and composing derivations –
precise descriptions of how contents of existing files are used to derive new files.
It is a domain-specific, purely functional, lazily evaluated, dynamically typed programming language.

One of the roles of the CLI tool is then to take this Nix language and build derivations in the `ATerm` format
which the nix daemon can understand.
This daemon's role is quite simply to execute a set of arguments and a builder in a clean environment
and put the output at a specific path, usually under `/nix/store`.

```nix
derivation {
  name = "my-test";
  system = "aarch64-darwin";
  builder = "/bin/bash";
  args = [ "-c" "/bin/mkdir $out && echo 'hello from nix' > $out/hello.txt" ];
}
```

The above is a basic derivation.
Using `nix-build test.nix` will build the derivation, put the file into the nix store with the `.drv` extension
and then asks the daemon to build it.
The daemon will, in a clean environment, execute the given args with the given builder.
In the example from above it will write `hello from nix` to a file in the store.

```bash {lineNos=false}
$ nix-build test.nix
this derivation will be built:
  /nix/store/h76qpn5s4aj3cpp1sc8xqblmwa307vy5-my-test.drv
building '/nix/store/h76qpn5s4aj3cpp1sc8xqblmwa307vy5-my-test.drv'...
/nix/store/a6lyz75jf2hgfryxfi6pkk3sivm7g5z3-my-test
```

The store location is determined by a hash of the derivation file.

```bash
$ cat /nix/store/a6lyz75jf2hgfryxfi6pkk3sivm7g5z3-my-test/hello.txt
hello from nix
```

and it contains our created file!

The real power however comes from the dependencies tree you can build using derivations.

```nix
let foo = derivation {
  name = "foo-derivation";
  system = "aarch64-darwin";
  builder = "/bin/bash";
  args = [ "-c" "/bin/mkdir $out && echo 'hello from foo-derivation' > $out/hello.txt" ];
}; in
derivation {
  name = "my-derivation";
  system = "aarch64-darwin";
  builder = "/bin/bash";
  args = [ "-c" "/bin/mkdir $out && echo 'foo-derivation is at ${foo}' > $out/hello.txt" ];
}
```

Running `nix-build test.nix` will now generate

```bash {lineNos=false}
$ nix-build test.nix
these 2 derivations will be built:
  /nix/store/sbkmk5a7kdrcr8d1vbalnz62xqfm8knq-foo-derivation.drv
  /nix/store/9r02j45606rgsjbwvcdfazw4xh522prv-my-derivation.drv
building '/nix/store/sbkmk5a7kdrcr8d1vbalnz62xqfm8knq-foo-derivation.drv'...
building '/nix/store/9r02j45606rgsjbwvcdfazw4xh522prv-my-derivation.drv'...
/nix/store/xgl8ksq7fy982f7791m0s18hwhhybfan-my-derivation
```

Let's take a look at one of these `.drv` files.

```bash {lineNos=false}
$ cat /nix/store/9r02j45606rgsjbwvcdfazw4xh522prv-my-derivation.drv
Derive([("out","/nix/store/xgl8ksq7fy982f7791m0s18hwhhybfan-my-derivation","","")],[("/nix/store/sbkmk5a7kdrcr8d1vbalnz62xqfm8knq-foo-derivation.drv",["out"])],[],"aarch64-darwin","/bin/bash",["-c","/bin/mkdir $out && echo 'foo-derivation is at /nix/store/383lfbdfj5isb0bzv7d26ls492dr3db3-foo-derivation' > $out/hello.txt"],[("builder","/bin/bash"),("name","my-derivation"),("out","/nix/store/xgl8ksq7fy982f7791m0s18hwhhybfan-my-derivation"),("system","aarch64-darwin")])
```

Hm, not very readable.
Here it is formatted and annotated:

``` {guessSyntax=true}
Derive(
    -- outputs: (name, store path, hash algo, hash)
    [("out", "/nix/store/xgl8ksq7fy982f7791m0s18hwhhybfan-my-derivation", "", "")],

    -- input derivations: (path to .drv, which outputs of it we need)
    [("/nix/store/sbkmk5a7kdrcr8d1vbalnz62xqfm8knq-foo-derivation.drv", ["out"])],

    -- input sources: plain store paths (not derivations) we depend on
    -- e.g. a patch file or script copied directly into the store
    [],

    -- system
    "aarch64-darwin",

    -- builder executable
    "/bin/bash",

    -- args to builder
    ["-c", "/bin/mkdir $out && echo 'foo-derivation is at /nix/store/383lfbdfj5isb0bzv7d26ls492dr3db3-foo-derivation' > $out/hello.txt"],

    -- environment variables available in the build sandbox
    [
      ("builder", "/bin/bash"),
      ("name",    "my-derivation"),
      ("out",     "/nix/store/xgl8ksq7fy982f7791m0s18hwhhybfan-my-derivation"),
      ("system",  "aarch64-darwin")
    ]
  )
```

As you can see, the derivation already contains the resolved path from our `${foo}`.

This is the bedrock on which the rest is built.
Nix-darwin, NixOS, nixpkgs all in the end evaluate down to these derivations that the builder executes.

## nixpkgs

Nixpkgs is a very elaborate use of this whole basic machinery, layering derivation on derivation in order to do something useful:
build packages.

Using `nix derivation show` we can get the derivation for a specific package formatted in JSON.
In this case let's look at the derivation of the `hello` package using `nix derivation show nixpkgs#hello`.

The output is rather long and you can [take a look at the whole derivation here](/files/nix/hello-drv.json).
If we break it down we can see some of the same things as in our earlier simple examples.
4 input derivations:

- `4pfh4419sbdw2c830hid1992rifx3jsr-hello-2.12.3.tar.gz.drv`: the input source code, a tar archive downloaded from the internet
verified with a hardcoded hash
- `6fv6ygbc6p4d2qwnpvpfcfk3bc00nmqs-version-check-hook.drv`: checking the output version matches
- `vz888daw9ar2b89n7rzn3iql09lkyy54-bash-5.3p9.drv`: the bash builder used. Instead of using the bash from the host system,
use a known, fixed bash version
- `zqzclxrikldl7wl6m65g8h4inf8xf95y-stdenv-darwin.drv`: a derivation that has standard build tools as outputs,
like gcc, make, autoconf and so on.

It also defines one output `chnjf7vj55192vmdd2kfjjdlhzj7vill-hello-2.12.3`.
We can build this derivation using `nix build nixpkgs#hello`.

If we check the nix store we can find the built package under the output path:

```bash {lineNos=false}
$ ls --tree --icons=never /nix/store/chnjf7vj55192vmdd2kfjjdlhzj7vill-hello-2.12.3
/nix/store/chnjf7vj55192vmdd2kfjjdlhzj7vill-hello-2.12.3
├── bin
│   └── hello
└── share
    ├── info
    │   └── hello.info
    └── man
        └── man1
            └── hello.1.gz
```

And we can also run it

```bash {lineNos=false}
$ /nix/store/chnjf7vj55192vmdd2kfjjdlhzj7vill-hello-2.12.3/bin/hello
Hello, world!
```

or as a shortcut for building and running the binary we can use `nix run`.

```bash {lineNos=false}
$ nix run nixpkgs#hello
Hello, world!
```

More complicated packages are in the end more complicated versions of this derivation format.
For example the derivation and output for git is a lot more complicated.
You can check this out for any package using `eza --tree $(nix path-info nixpkgs#git)`

The way these derivations are defined is built on top of a lot of abstractions.
You won't see a `derivation =` in the Nix source code for `hello` but rather a `stdenv.mkDerivation`.
However in the end it's all just nix code.
The `hello` package is a great entrypoint into reading these package nix files.
It is actually quite simple to read and [can be found on Github](https://github.com/NixOS/nixpkgs/blob/eeac4f06ba6d4c5540c4838d13b31a2cbe0e104b/pkgs/by-name/he/hello/package.nix).

## nix-darwin

As previously described the nix daemon doing the building doesn't actually care about what it's building or doing.
It takes a builder, some args and executes it in a clean environment.

Now nothing stops us from writing a file which applies changes to your computer.
We could for example write a derivation which writes a bash script modifying settings on the computer using `defaults` on macOS.
This is exactly what nix-darwin is doing.
When setting the name `system.defaults.dock.autohide = true`, that value will make it to the derivation
and write `defaults write com.apple.dock autohide -bool true` (simplified, what it actually writes looks different) in the activation script.
This activation script is then executed when running `darwin-rebuild switch`.

Virtually all other options to nix-darwin work in a similar way.
It adds program calls to the activation bash script, puts certain directories in your path, collects the binaries under a `bin`
directory, can optionally call Homebrew to install casks, if you configure the homebrew module.

Nix-darwin links its current generation under `/run/current-system`.
Looking at it we can see that it's merely a symlink into the nix store.

```bash
$ ls -l /run
current-system -> /nix/store/ppaa417fy77jlyxscxmp150shcxqavwh-darwin-system-26.05.8c62fba
```

Most things will then reference `/run/current-system`.

```bash
$ which fd
/run/current-system/sw/bin/fd
```

This means to switch to a new generation the symlink of `/run/current-system` can just be updated to a new path in the store to
switch to a completely new system.

Taking a look at the `darwin-system` output reveals the activation file.

```bash
$ ls -l --icons=never /nix/store/ppaa417fy77jlyxscxmp150shcxqavwh-darwin-system-26.05.8c62fba
.r-xr-xr-x  86k root  1 Jan  1970 activate
.r-xr-xr-x 1.9k root  1 Jan  1970 activate-user
lrwxr-xr-x    - root  1 Jan  1970 Applications -> /nix/store/b0fmqw3gxz4z6d10kkjzizgidpbcni0j-system-applications/Applications
dr-xr-xr-x    - root  1 Jan  1970 darwin
.r--r--r--  11k root  1 Jan  1970 darwin-changes
.r--r--r--   13 root  1 Jan  1970 darwin-version
lrwxr-xr-x    - root  1 Jan  1970 darwin-version.json -> /nix/store/zpvxir31dqnphddqznvxzqsgfp0qz0kn-darwin-version.json
lrwxr-xr-x    - root  1 Jan  1970 etc -> /nix/store/iv3v18bpq53irp7nb66lck27jxxbs30m-etc/etc
dr-xr-xr-x    - root  1 Jan  1970 Library
lrwxr-xr-x    - root  1 Jan  1970 patches -> /nix/store/wddxxfck8jcvvs160lg1sairb5lws3a0-patches/patches
lrwxr-xr-x    - root  1 Jan  1970 sw -> /nix/store/lgr68xyzi13fxc8y13saw351alz7gh00-system-path
.r--r--r--   14 root  1 Jan  1970 system
.r--r--r--   71 root  1 Jan  1970 systemConfig
dr-xr-xr-x    - root  1 Jan  1970 user
```

As you can see the `sw` directory, the path where our `fd` binary lives, in the end is also just another link
to another output in the store.

Here we can also find the `activate` script.
This is the script that in the end actually applies the system configuration
and gets executed when running `darwin-rebuild switch`.

Taking a look at some of the inputs to our `darwin-system` derivation:

- `0xw18pzql06qkpq21wiyqpp4czpbi37j-launchd.drv`: macOS launchd services
- `rfla1va90zrlq17vndnq1kkxxyaa273k-etc.drv`: configuration files in `/etc`
- `sx321ymsaa0nrib2gfqbf36ryarnimqi-Brewfile.drv`: Brewfile for homebrew integration

The darwin-system derivation takes all these inputs, and writes out its own `$out/activate` script.

If you also run `nix-darwin` you can inspect your own system derivation file using `nix derivation show $(readlink -f /run/current-system)`,
or even recursively by adding the `-r` flag to `nix derivation show` (Warning, this is a huge file, 25MB on my relatively simple system).

## Conclusion

In the end it's all derivations all the way down.
Derivation on derivation layered to form a clean dependency tree and do some useful work,
whether that is building a package or writing an activation script to configure your computer in various ways.
Combined with the hash-based store mechanism,
the foundation makes for a really cool structure to build on top of and the community has clearly done that in impressive ways.
There's a lot more interesting uses of the nix machinery and I haven't even really begun to explore them all.

Looking at the stack from the bottom up really helped me understand what nix actually is and does under the hood.
I will be publishing a follow up to this, looking at flakes and how to actually set up nix-darwin from first principles.
