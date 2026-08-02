-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Lake
open Lake DSL System

package leancurl

def pkgConfigFlags (args : Array String) (lib : String) : IO (Array String) := do
  let out ← IO.Process.run { cmd := "pkg-config", args := args.push lib }
  return out.trimAscii.toString.splitOn " " |>.filter (· ≠ "") |>.toArray

-- Built as a standalone shared library (linked against system libcurl directly,
-- via a plain `cc -shared` call) rather than a `moreLinkObjs` object file, because
-- `moreLinkObjs` is deliberately excluded from per-module dynlib builds (see
-- `Module.recBuildDynlib` in Lake), which breaks `precompileModules`/interpreter
-- support for the `@[extern]` declarations. Building our own self-contained
-- `.so` also avoids re-adding `-L/usr/lib/...` to the final executable's link
-- line, which previously caused the linker to resolve `-lc` against the
-- system's dynamic libc instead of Lean's bundled static one.
target curlShimDynlib pkg : Dynlib := do
  let srcJob ← inputTextFile <| pkg.dir / "c" / "curl_shim.c"
  srcJob.mapM fun srcFile => do
    addPlatformTrace
    let cflags ← pkgConfigFlags #["--cflags"] "libcurl"
    let libs ← pkgConfigFlags #["--libs"] "libcurl"
    let cArgs := #["-I", (← getLeanIncludeDir).toString] ++ cflags
    let oFile := pkg.buildDir / "c" / "curl_shim.o"
    let libFile := pkg.sharedLibDir / (nameToSharedLib "leancurl_shim")
    let art ← buildArtifactUnlessUpToDate libFile (ext := sharedLibExt) (restore := true) do
      compileO oFile srcFile cArgs "cc"
      compileSharedLib libFile (#[oFile.toString] ++ libs) "cc"
    return { path := art.path, name := "leancurl_shim" : Dynlib }

@[default_target]
lean_lib Leancurl where
  -- Needed so the interpreter (used while elaborating downstream modules in this
  -- package, e.g. during `lake build`) can run the `@[extern]` `globalInit` call
  -- inside FFI.lean's `initialize` block.
  precompileModules := true
  moreLinkLibs := #[curlShimDynlib]

-- Declared so Lake knows to build `Test.FixtureServer`: modules a `lean_exe`
-- imports are only tracked if some `lean_lib` in the package claims them.
lean_lib Test

@[test_driver]
lean_exe leancurlTest where
  root := `Test.Main
