-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Lake
open Lake DSL System

package leancurl

def pkgConfigFlags (args : Array String) (lib : String) : IO (Array String) := do
  let out ← IO.Process.run { cmd := "pkg-config", args := args.push lib }
  return out.trimAscii.toString.splitOn " " |>.filter (· ≠ "") |>.toArray

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
      let undefinedArgs := if System.Platform.isOSX then #["-undefined", "dynamic_lookup"] else #[]
      compileSharedLib libFile (#[oFile.toString] ++ libs ++ undefinedArgs) "cc"
    return { path := art.path, name := "leancurl_shim" : Dynlib }

@[default_target]
lean_lib Leancurl where
  precompileModules := true
  moreLinkLibs := #[curlShimDynlib]

lean_lib Test

@[test_driver]
lean_exe leancurlTest where
  root := `Test.Main
