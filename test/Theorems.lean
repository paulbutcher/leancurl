-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

module

import Leancurl

namespace Leancurl.Method

/-- The verbs libcurl is handed for the non-`custom` methods are distinct, so no two
methods can silently share a request line. -/
theorem toVerb_inj_builtin :
    ∀ m₁ ∈ [Method.get, .post, .put, .delete, .patch, .head],
    ∀ m₂ ∈ [Method.get, .post, .put, .delete, .patch, .head],
    m₁.toVerb = m₂.toVerb → m₁ = m₂ := by
  simp only [List.mem_cons, List.not_mem_nil, or_false]
  rintro m₁ (rfl|rfl|rfl|rfl|rfl|rfl) m₂ (rfl|rfl|rfl|rfl|rfl|rfl) h <;> simp_all [toVerb]

/-- An empty verb would make libcurl fall back to its default method rather than fail. -/
theorem toVerb_ne_empty (m : Method) (h : ∀ v, m ≠ .custom v) : m.toVerb ≠ "" := by
  cases m <;> simp_all <;> decide

end Leancurl.Method
