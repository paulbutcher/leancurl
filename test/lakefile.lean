-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Lake
open Lake DSL

package test where
  builtinLint := true

require leancurl from ".."

require plausible from git "https://github.com/leanprover-community/plausible" @ "v4.32.0"

lean_lib Tests where
  roots := #[`Main, `FixtureServer, `Properties, `Theorems]

@[test_driver]
lean_exe runTests where
  root := `Main
