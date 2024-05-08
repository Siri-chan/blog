---
tags:
  - succ
---

# Definitions of Fn Macros
Much like GCC and other compilers, there are a few special macros that `succ` defines, for compatability, as well as just to be useful.
These are all defined within [src/preprocessor/macros.rs](https://github.com/Siri-chan/succ/blob/master/src/preprocessor/macros.rs), using a function that can be added as a parameter to our `Definition::Fn()` enum variant.

-  `__FILE__` uses the filename that we keep hold of when we compile (for this purpose), and isn't that interesting.
- `__LINE__` is buggy, and I'm not certain how to fix it, so I have no intention of covering it in much depth.
- `__DATE__` and `__TIME__` bring in a dependency on `chrono` which I would love to drop back to a feature ( #todo so I see this again) before `succ` goes stable. You may note that these are in UTC by design.

As always you can look into the logic of each of these in the source, but they aren't too compilcated, and it wouldn't be hard to add more builtins if need be.
``