---
tags:
  - succ
publish: 2024-05-08
---
<!-- 
This article and those that follow it are informational, documenting the process, my decisions, and the things I learned while building `succ`. Consider the contents of this text to be protected under my copyright.
I expect it to not be reproduced in any form without my expressed written permission.
-->

I have spent a **lot** of time recently, developing my C compiler, [`succ`](https://github.com/Siri-chan/succ). It has become a bit of an obsession, and I have found myself spending a lot of my time working on it.
Before I discuss in great detail, I want to acknowledge the many, many resources I accessed while working on `succ`, such as:
- [Alan Holub's *Compiler Design in C*](https://holub.com/compiler/), which I spent about $\yen5000$ ordering from [Amazon](https://a.co/d/jhmGgPX), so that I could read it on paperback. It's a good read, and has definitely taught me some things, but it's rather archaic now, and the code snippets are outdated and hard to read, even for somebody who is apt with *comparatively-modern* C.
- [Christopher Hanson's *A Retargetable C Compiler: Design and Implementation*](https://github.com/drh/lcc), which is more expensive, and I didn't end up purchasing, instead reading the shorter public paper on `lcc`, published on [the ACM Website](https://dl.acm.org/doi/pdf/10.1145/122616.122621). It isn't a full experience, but it does describe the core of the implementation in relatively simple terms.
- [Charles Fischer's *Crafting a Compiler*](https://amzn.asia/d/hfou3BZ), particularly the 2010 edition, which I got given as a gift, *ages* ago. I can't recommend this book, as the pseudocode puts me off and I don't like the object-oriented structure, but I did learn quite a bit from it.
- [Ueyama Rui's *ChibiCC*](https://github.com/rui314/chibicc) was also very interesting, though, at the time of writing, Rui's book is yet to be released, there is a lot that can be learned from the repository, and is still worth studying.
- and, of course: [Dennis Kernigham and Brian Ritchie's *C Programming Language Second Edition*](https://amzn.asia/d/h4rLNq9). Which was useful as a language reference, and is just generally so elegantly and clearly written that it is a **must have** for anybody even remotely interested in C, UNIX or really just programming in general.
Interestingly, there aren't many modern blog-post series that cover this topic, though, it is a rather complex challenge, so it does make sense.
These works were all good references, whenever I was lost, I typically found myself gravitating toward one of these implementations.
Reading [LLVM's `clang` documentation](https://clang.llvm.org/docs/InternalsManual.html) and occasionally even `gcc`'s source code was in order, when I found myself getting really stuck.

This project was an immense challenge, and existed to fulfill a very niche requirement. I wouldn't recommend doing this, not even as an experienced developer. It isn't a good learning exercise or a test of skills, though it is a rather demanding task.
If you need a C compiler on an architecture that doesn't currently have one, I would suggest porting an existing compiler.

# Prelude
I am not a new developer. I have written a lot of code before, some very complex. I own books on the subject material and have experience writing more trivial compilers (like [[brainfuckers]]) in particular.
`brainfuckers` also directly links with my requirements for this project. As you may be aware, `brainfuckers` has the ability to transpile[^1] it's input to C code. This is all well and good, but there was no idiomatic way to compile that C source into binary. Rust's `cc` crate seemed promising, but `cc` cannot directly compile a `String` down into a file, it would need to be written out. Similarly, for platform-independence reasons, I couldn't just invoke a C compiler through a `std::process::Command`. I would have needed a C compiler written (at least partially) in Rust, with support for runtime compilation, and nothing like that existed at the time.
Not long after that, I realised how long some of my `awk` scripts were taking.
For context, I was adding the year 2023 to the copyright comment for a large repository of code I was working on at work, and I thought to myself: 

> I wish I could just write this header to one file, run a command, and have it fix all of this for me.

Turns out, that's totally an option. While waiting for `awk` to finish, my brain thought of the following 'C'-like Haskell source file (I gave this file the extension `.chs`, which implies a `.hs` file that contains C macros), and a related header.

```c title="copyright.chs"
#define COPYRIGHT_START_YEAR 2022
#include<copyright.h>
```

```haskell title="copyright.h"
-- Copyright (c) <My Workplace> COPYRIGHT_START_YEAR-2023.
-- All Rights Reserved.
```

A C compiler, such as `gcc`, would theoretically expand the text file out to
```haskell title="copyright.hs"
-- Copyright (c) <My Workplace> 2022-2023.
-- All Rights Reserved.
```
before compiling anything.

I was only half-right.
Every C compiler that I looked into expanded the text-file in the same step as tokenisation, meaning that - at best - the compiler would be able to restructure the tokens into inexact source code (and output it to `stdout`, not directly to a file), and at worst, it would complain about incorrect or otherwise unexpected tokens, and not expand anything but valid C code.
<!-- note to self:  succ should actually have a preserve-comments-through-preprocessing flag -->
This obviously isn't what I needed, so I had it set in my mind that I wanted to write a C preprocessor of the quality I wanted in this case.

Then, it came to me. 
> What if I just built my own C compiler?
> Then I could have my preprocessor do exactly this!
> ...
> and, I could make `brainfuckers` actually compile its transpiled[^1] C code.

So, that's what I did.
I sat down, and ran the command that would drastically change what I would do with my spare time.
```sh ln=false
cargo new succ
```
The name `succ`, was just something I thought was funny at the time, because it ended with `cc`, as is traditional for C compilers, and it fit great with the name I'd thought of for the standalone preprocessor - `succ-pp`.

# Preparations

## Initial Thoughts

First, I brainstormed with some friends about:
1. What I wanted from `succ`.
2. What `succ` should stand for.
3. Why nobody had written a C compiler in Rust before.
4. How I should deal with the abnormal style of preprocessor.
5. How I should setup the program's command line arguments, compared to - say - `gcc`.

Of course, we found answers for each of those questions:
1. A robust, sensible compiler that can comply with *at least* ANSI's C89 Standard, and at a bearable pace.
2. **S**iri's **U**ninteresting **C C**ompiler. Simple enough.
3. Probably just the relative youth of the language, and the existence of more mature compilers.
4. Just split the tokeniser into a seperate step.
5. Make them similar enough that they aren't hard to pick up, but different enough that they fit my use-case better than `gcc`'s.

## Some Basic Preparation

Next, I set up my cargo project. At first, I thought it could just be a binary, but I eventually realised that a library + binary setup would make more sense.
I built what I would consider a very basic template for a command-line program, with:
1. A build script that gets the version from `Cargo.toml`, the commit hash from `git rev-parse HEAD`.
2. Parsing for command line arguments, with two basic ones; `--help` and `--version`.
3. Functions that print help-text and version-text when one of the command line arguments are found.
All of these tasks are trivial, but there are some decisions I did make:
- I used a `VecDeque`, rather than a `Vec` for handling argument parsing.[^2]
- I immediately `pop` the $0^\text{th}$ argument, which is *in most cases*[^3] the program's name.
- I used a build script and the `env!` macro to grab the version number from `Cargo.toml` without needing to update any code, upon bumping the version.
- I store my command-line flags in a `Flags` structure. This makes accessing relevant flags quicker, and inadvertently made the jump to a library considerably easier, later.

## Reading and Understanding Files

Obviously, in order to process files, `succ` needs a robust method of reading and storing them.
For this, I use `succ`'s `SourceFile` structure.
`SourceFile`s are a very simple struct. Just to show how simple it is, here is the entire declaration:
```rust ln=false
#[derive(Clone, PartialEq, PartialOrd)]
pub struct SourceFile {
    pub filename: String,
    pub contents: String,
}
impl Debug for SourceFile {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.filename)
    }
}
```
The most complicated part is changing their `Debug` display behaviour, so that they don't print the entire file's contents, without that code (which isn't strictly necessary, it just makes debug printing easier), the whole declaration is 5 lines.

`SourceFiles` are very convenient, as they can be passed around, just like a `String`, and can hold both the filename and the file contents in a descriptive and sensible way. `succ` needs to keep track of filenames, primarily for the `__FILE__` macro (which I touch on later), and for outputting intermediate files, which are generated for each source file.

`SourceFile`s are also easy to construct:
```rust ln=false
SourceFile {
	filename: arg.clone(),
	contents: fs::read_to_string(&arg)
		.expect(&format!("Failed to read Source File '{}'", &arg)),
}
```
This is, again, very simple to work with, and therefore convenient (especially when I move to a library).

With all of my preliminary work out of the way, it was time to work on the first real challenge of the project.

# The Preprocessor

That was one of my main goals for `succ` was a text-to-text preprocessor. Since I can't really work on the actual compilation side of `succ` until it has a preprocessor, because the code I could actually test without preprocessor directives would have *practically*[^4] no I/O, and would therefore be difficult to check for unintended behaviour.

## Invoking the Preprocessor

My first challenge was actually invoking my preprocessor function.
At first, I did this synchronously, and actually shared some mutable information between files.
This was a bad idea, partly because the entire compilation process (until linking) is completely per-file, and so sharing mutable information would make compilation dependent on other files, and also make `async` preprocessing impossible without `Mutex`es and a lot of needless complexity.
Through a lot of iteration, and use of the wonderful `futures` crate, I settled on this:
```rust title="main.rs" ln=262
let source_files = flags.source_files.clone();

let promises = source_files.iter().map(|file| async {
	log::debug!("Preprocessing file: {:?}", file.clone());

	preprocessor::process(
		&file.clone(),
		/* macros are defined per-file */
		&flags.include_dirs,
	)
	.await
});

flags.source_files = block_on(join_all(promises));
```
With this setup, there is no mutable information given to the preprocessor, and all files are processed asynchronously, in parallel.
In theory, I don't need to wait for all of the preprocessing threads to join before moving onto the next steps, and I could just do everything in the one `async` block, but I feel that it is worth the performance hit, because with a method like this, the program can guarantee that a step has completed, when that `block_on` call succeeds.[^5]

## Trigraphs

Trigraphs are an oft-forgotten feature of older programming languages and typesetting software.
As many old keyboards (and pre-ASCII character sets) didn't have support for all the characters we have now, C contains a system for typing less-common characters, even when your keyboard doesn't natively support them.
These are called *Trigraphs*, and they are a character, preceded by a double question-mark (`??`).
While they are oft-forgotten, and many modern programs have no support for them at all, C89 expects them do be dealt with before any other preprocessing step.
Here is a full list of the trigraphs supported in C89: [^11]

| Trigraph | Translation |
| -------- | ----------- |
| `??=`    | `#`         |
| `??/`    | `\`         |
| `??'`    | `^`         |
| `??(`    | `[`         |
| `??)`    | `]`         |
| `??!`    | `\|`        |
| `??<`    | `{`         |
| `??>`    | `}`         |
| `??-`    | `~`         |

They are also simple to replace. If `succ` detects that a `??` sequence exists, it searches for, and replaces each trigraph in the file:
```rust title="preprocessor.rs" ln=207
let text = file.contents.clone()
	.replace("??=", "#")
	.replace("??/", "\\")
	// ...
	.replace("??>", "}")
	.replace("??-", "~");
```

## Purging the File

When a source file is given to an application, it contains several things that don't make it to the final product.

### Escaped Newlines
One such thing, is a newline that is escaped with `\` (ie. either `\\`+`\n` or `\\`+`\r`+`\n`).
These need to be removed before pre-processor directives can be handled, as in many cases, multi-line `#define` definitions are written as such:
```c ln=false
#define COMPLEX_FUNCTIONALITY \
int main(void) \
{ printf("Hello, World!"); }
```
Neglecting to remove these escaped newlines will cause unintended behaviour within a macro.
Similarly, something like this would work incorrectly:
```c ln=false
#define PI 3
P\
I

// expected output
3
// output if newline is escaped later in the process
PI
```
### Comments
Similarly, there are comments. You should already know what these are, but these also must be purged early into a file, or similarly unintended behaviour can occur, as multi-line comments need to be treated the same as escaped newlines:
```c ln=false
#define PI 3
P/*
	literally anything can go here
*/I

// expected output
3
// output if comment is escaped later in the process
PI
```
*Oddly enough, `gcc` actually gets this behaviour wrong, but not with escaped newlines.*

Perhaps interestingly, currently, `succ` supports single-line (`//`) comments. These weren't introduced until C99, but the crate which I lazily used to remove comments supports them, and they are convenient, so I don't mind.

## Macros and Directives
Once we have purged these preliminary sections, we proceed through the file line-by-line, running directives, and expanding macros. Both of these are rather complex, interesting and important parts of the compiler, so we'll go into a lot of detail here.

### Processing Directives
In C, the preprocessor relies on a sort of meta-programming language, called directives.
These must start at the beginning of a line, and they all begin with a `#`. `#include`, `#define`, etc. are common examples of these, but there are also less common directives, like `#error`. `succ`, of course, aims to support all of these.

However, before we can get onto directive-specific behaviour, we need to know how `succ` detects and parses the directive name.
`succ` is quite lenient with directive detection, trimming any preceding whitespace from each line, before processing it.
Then, if the line (with its preceding whitespace removed) starts with a `#`, we run `process_directives(...)`. 

In this function, we use the `str.starts_with(pat)` function to detect what directive is being used.[^6] 
One convenience of this function, is that there are multiple directives, with similar functionality that all begin with `#if`, and we can quickly identify if the directive is any of them, using `trimmed_line.starts_with("#if")`, short-circuiting the function, if not.

#### `#if` directives
Thanks to the behaviour of these directives, and how they impact the structure of a source file, we have to handle these before any other directives, which is why one of the first things we call in `process_directives(...)` is 
```rust title="preprocessor.rs" ln=367
directives::process_ifs(trimmed_line, macros, ifs, i);`
```
*where `trimmed_line` is the line of the file, `macros` is a `Vec` containing macro definitions* (which we need for `#ifdef` and `#ifndef` - a data structure that I will talk about later), *`ifs` is a `Vec<If>`* (I'll touch on this in a moment), *and `i` is the line number.*

The `If` data structure is a small, simple data structure, that stores the location and state of an `#if` directive.
```rust title="preprocessor.rs" ln=262
#[derive(Debug)]
/// Represents a `#if*` directive in the preprocessor.
pub struct If {
    location: usize,
    enabled: bool,
}
impl If {
    /// Generates a new [`If`]. Convenience function.
    pub fn new(i: usize, c: bool) -> Self {
        Self {
            location: i,
            enabled: c,
        }
    }
}
```
We need to store the state of the `#if`, because the processor requires every condition to conclude with a `#endif` directive, and so, even if the contents of the `#if` are true, and it functionally does nothing, we need to store it, for the sake of the `#endif`.

A `Vec<If>` is really convenient for storing the state of the conditions, because we can push a new `If` to it, whenever we encounter any `#if`-type directive, and just `pop()`, when we encounter the `#endif`.

In `process_ifs(...)`, we handle `#ifdef` and `#ifndef`, as well as `#endif`. `#if <CONDITION>` is currently unimplemented, because I haven't found the patience to properly programmatically evaluate a condition.

The process for `#ifdef`, and also, by extension, `#ifndef` [^7] is rather simple; We just pull the rest of the characters from the line in whitespace-separated chunks, and check if a macro with the name of the first non-empty chunk exists.

`#endif` is also very trivial in it's behaviour.
When it is encountered, we just pop an `If` from our `Vec`, or error, if there are none to pop.
```rust title="preprocessor/directives.rs" ln=80
let corresponding_if = match ifs.pop() {
	Some(i) => i,
    None => return Err(PreprocessingError::OverclosedIf),
};
```

Once we've handled our if directives, we check if any `If`s are not enabled, and if so, we short-circuit, as nothing else should be processed, given the if is closed.
```rust title="preprocessor.rs" ln=368
for _if in ifs {
    if !_if.enabled {
        // We return empty if any `#if*` is disabled and the line is not an `#endif`
		return Ok(Vec::new());
	}
}
```
*Also note, that `if` is not a valid variable name, as it is a reserved keyword in Rust.*

We the have a little behavior to ignore all lines that aren't directives, whenever an `#if` directive should disable text, and then a check that all of the `#if` directives are closed before the end of the file.

#### Trivial Directives
Some directives have incredibly simple behavior. `#error` just returns an error message, `#using` is unsupported, `#pragma` does nothing, as I haven't defined any pragmas yet.
`#line` also has no behaviour, as I have no idea how `succ`'s preprocessor can, in it's current state, support the functionality that `#line` requires, so I have left it out.

#### `#include`
`#include` is the next meaningful directive that we process.
Like `process_ifs(...)`, we have a function in the `directives` module, dedicated to the behaviour of `#include`.
Its signature is as follows:
```rust ln=false
directives::include(
	trimmed_line,
	cd_scan_directories,
	specd_scan_directories,
	include_dirs,
	i,
	file
)
```
*where `trimmed_line` and `i` are the same as above, the two `*_scan_directories` variables, and the `include_dirs` variable are cached lists of directories* (who's purpose will become very obvious in a moment) *and `file` is a copy of the `Sourcefile` that we are currently operating on.*

The code for `#include` has several steps:
1. It finds the filename either enclosed in `<>` or `""`.
2. It figures out what directories to scan based on the cached lists, or generates the relevant lists if they haven't already been generated.
3. It scans those directories to find a matching filename.
4. It reads that file to a string.
5. It implants that file into the current `Sourcefile`

Most of these steps are relatively simple. 
- Finding the filename is the same process as a lot of the rest of our text manipulation. We also store what delimiter (`<> (IncludeType::SPECD)` or `"" (IncludeType::CD)`) is used, because they behave differently.

- Generating our cached lists is trivial
```rust title="preprocessor.rs" ln=156
IncludeType::SPECD => {
	scan_directories = match specd_scan_directories {
		Some(ref v) => v.clone(),
		None => {
			let mut _tmp = default_scan_directories();
			for dir in include_dirs {
				_tmp.push(dir.clone())
			}
			*specd_scan_directories = Some(_tmp.clone());
			_tmp
		}
	}
}
```
This code simply checks if our `scan_directories` contains a value already, and gives it one if not. Very similar code is used for `IncludeType::CD`.

- Scanning these directories is as simple as using Rust's `std::fs` utilities, specifically `PathBuf.read_dir()`.
	`succ` uses an asynchronous method, `scan_dir(dir, search_file)` that recursively calls itself [^8] to scan through each directory and it's children to find the correct header file.

- Then, `succ` uses `std::fs::read_to_string()` to read the file out to a `String`.

- Finally, the String is placed within our file again by pushing it to a vector.

#### `#define` and `#undef`
When we define a macro, we store its info in a little data structure specifically for this process.

```rust ln=false
#[derive(Clone, PartialEq, PartialOrd, Debug)]
pub struct Macro {
    pub alias: String,
    pub args: Option<Vec<String>>,
    pub definition: Definition,
    pub can_undef: bool,
}
```

The structure is set up to be simple and still have everything we need.
- `alias` is the string we look for to replace.
- `args` is an option because it also allows us to much more easily differenciate between macros with and without arguments (ie. `#define PI 3` vs `#define PRINT(x) printf("%s", x)`)
- `definition` is it's own enum, because there are a few specific [[#^35c902|builtin macros]] that need to be implemented specifically. 
- Finally, we have `can_undef`, which is solely setup to prevent using `#undef` on built-in macros.
We hold a mutable `Vec<Macro>` for each file, that gets borrowed by `define()` and `undefine()`.

##### `define()`
In define, we pull the different components of the macro out from the line:
```rust ln=false 
let mut words = trimmed_line.split(' ');
//remove the "#define" from the iterator
words.next(); 

//extract the name of the macro
let mut macro_name;
if let Some(macro_name) = words.next() {
	macro_name = name;
} else {
	return Err(PreprocessingError::EmptyDefine);
}

// find the actual definition (alternatively, we could probably `collect()` the iterator here)
let mut tail_start = match trimmed_line.find(macro_name) {
	Some(u) => u,
	// we know the line contains this string, because we took it from the line.
	None => unreachable!(),
} + macro_name.len();
```
`macro_name` directly maps to `alias` in the `Macro` struct.

As mentioned before, some macros have arguments. We handle these now, because our behavior diverges a bit depending on if or not we have arguments.
```rust ln=false
let mut args: Option<Vec<String>> = None;
if macro_name.contains('(') {
	let Some(i) = macro_name.find('(') else {
		// The macro name contains '(', we already know this.
		unreachable!()
	};
	macro_name = &macro_name[0..i];
	let j = match trimmed_line.find('(') {
		Some(u) => u,
		// We have already checked for .contains()
		None => unreachable!(),
	} + 1;
	let Some(k) = trimmed_line.find(')') else {
		log::error!("Macro definition contains unclosed argument declarator '('.");
		return Err(PreprocessingError::UnclosedDefineArgs);
	};
	tail_start = k;
	let args_section = &trimmed_line[j..k].chars();
	let mut arg = Vec::new();
	let mut s = String::new();
	for c in args_section {
		if !c.is_ascii() {
			//ignore
			continue;
		}
		if c.is_ascii_whitespace() {
			//todo we should only continue if this is after a comma
			continue;
		}
		if c == ',' {
			arg.push(s.clone());
			s = String::new();
			continue;
		}
		s.push(c);
	}
	arg.push(s.clone());
	args = Some(arg);
}
```
This code does quite a lot, but a lot is just verbose and explicit error handling, so let's break down just the actual behavior.
```rust ln=false
// Only perform this if the macro has arguments
if macro_name.contains('(') {
	// Remove the args from the macro name
	macro_name = &macro_name[0..macro_name.find('(')];
	
	// Find the start and end of the argument list
	let j = trimmed_line.find('(') + 1;
	let k = trimmed_line.find(')');
	
	// Update the start of the macro's definition to be after all iof the arguments are listed.
	tail_start = k;
	
	// Create some containers that we will mutate with argument creation.
	let mut arg = Vec::new();
	let mut s = String::new(); // Note that s needs to have the same scope as `arg`, or rustc complains.
	
	// Pull all of the characters individually from the argument list.
	let args_section = &trimmed_line[j..k].chars();
	
	for c in args_section {
		if !c.is_ascii() || c.is_ascii_whitespace() {
			//ignore any non-ascii, and any whitespace
			continue;
		}
		// Conclude one argument from the list and start another.
		if c == ',' {
			arg.push(s.clone());
			s = String::new();
			continue;
		}
		// Otherwise, just push the character to the argument name.
		s.push(c);
	}
	// Push the final argument name and then wrap up our vector to fit the `Macro` struct requirements.
	arg.push(s.clone());
	args = Some(arg);
}
```
I actually neglected to write this functionality for a while, because figuring this parsing logic out was actually rather challenging[^9]. 

Finally, `define()` pulls out the tail of the line, and assigns `definition` appropriately.
```rust title="preprocessor/directives.rs" ln=336
 let tail = 
	String::from(&trimmed_line[tail_start + 1..trimmed_line.len()])
	.trim()
	.to_owned();
let definition = if tail.is_empty() {
	Definition::Empty
} else {
	Definition::String(tail)
};
macros.push(Macro {
	alias: macro_name.to_string(),
	args,
	definition,
	can_undef: true,
});
```
This code is hopefully self-explanatory, and not super important for this behavior.

##### `undefine()`
This is also a super trivial function. We search over our macro list and then remove the macros that have a matching name.
For some reason, I return an empty `Vec<String>` here, rather than nothing. 
<!-- Note to self: I should probably make this logic more consistent within succ. -->

### Substituting Macros
Macro substitution isn't awfully complicated, but does have some curiosities.
Firstly, we pull in whatever relevant line, and convert it to an owned string.
When we iterate over our macros, and then each occurrence of the macro in the text.

For each Macro, we handle it differently, depending on if the macro has arguments or not.
If it doesn't ave arguments, we just substitute whatever text.

```rust title="preprocessor.rs" ln=487 
let offset = match text.find(&_macro.alias) {
	Some(offset) => offset,
	None => unreachable!(), //we already know for certain that `text` contains `&_macro.alias`.
							//We checked this in the `while`.
};
log::debug!("Found macro {:?} at character {}.", &_macro, offset);
let replace = match &_macro.definition {
	Definition::Fn(f) => (f)(file.clone(), line_number),
	Definition::Empty => String::from(""),
	Definition::String(s) => s.clone(),
};
log::debug!("Replacing with definition: \"{}\"", replace);
text.replace_range(offset..(offset + _macro.alias.len()), &replace);
```

This is where our `Definition` enum comes in, as our different definitions help us with different behavior.
- `Definition::Empty` is just a empty defintion to use with `#ifdef`.
- `Definition::String` is a user-created string definition with or without arguments.
- `Definition::Fn` is used for a couple of special macros defined by the compiler, such as `__LINE__` and `__DATE__`[^10]. 
We behave accordingly with the enum, and then substitute the macro with its value. ^35c902

If it has arguments, we read the value to substitute, and then we do a pattern substitution, before proceeding as above.
```rust ln=false
let offset = text.find(&_macro.alias);
let line = &text[offset..text.len()];
let i = line.find(')').unwrap();
let line = &line[_macro.alias.len() + 1..i];
let argv = &line.split(',').map(|s| s.trim()).collect::<Vec<&str>>();

// Note that Fn Definitions cannot have arguments, and that empty defintions will never have content to replace.
let replace = match &_macro.definition {
	Definition::Fn(f) => (f)(file.clone(), line_number),
	Definition::Empty => String::from(""),
	Definition::String(s) => {
		let mut ss = s.clone();
		for (i, arg) in args.iter().enumerate() {
			let arg = arg.trim();
			ss = ss.replace(arg, &argv[i]);
		}
		ss
	}
};
text.replace_range(offset..offset + i + 1, &replace);
```
*Error handling and debug logs removed for brevity.*

# Conclusion

I think that covers everything there is to know about `succ`'s preprocessor. I have a couple more articles in the works covering other parts of `succ`, which I was writing as I worked on them, but need a lot of tidying and so on.

Even this article has a few things that I wanted to resolve before publishing, but eventually conceded to. If you grep `to self` in the source code for  this article, you will find a couple of things I still aim to implement

Until you see me again,
	**Siri.**

[^1]: Transpile - Rather than *compiling* (transforming source code to machine code), *transpiling* transforms source code into a different language's source code. 

[^2]: In some projects, I use a reversed `Vec`, and pop off of it's top, to parse the arguments in order. In `succ`, however, I ran some micro-benchmarks, and found that using `VecDeque::pop_front()`, and not modifying the order of `Args` was actually more performant than the (surprisingly costly) operation of reversing the `Args` into a `Vec`, even though `pop()` is quicker than `pop_front()`. Beyond that, if an argument that breaks the parse - such as `--version`, which prints the version information and immediately exits - is encountered, some of the time spent reversing the `Vec` is wasted.  *Note: The precise results of this benchmark are lost to time, and `cargo bench` is somehow **still** unstable and I couldn't be bothered to set it up, so I have no proof of this claim.*

[^3]: On some OSes, or when executing a command in some programming languages, `args[0]` can be specified by the user, or is just the first argument passed from the shell. `succ` considers this to be incorrect behaviour on the OS's end.

[^4]: The only input would be command-line arguments and the only output would be `main()`'s return value. This is because I would be unable to `#include` any system libraries, namely `stdio.h`.

[^5]: For example, if I have some broken C code, and I'm running `succ` with `-E` (*which expands preprocessor output to files*), and the entire process runs in async, a quick-to-preprocess source file may cause an error before a longer file can finish preprocessing, and in that case, `succ` cannot guarantee that every file will have been properly expanded, where if the program can only fail at the end of each step, `succ` (and the user, who now has to debug their code) can be confident that the previous steps were successful for all files.

[^6]:  Once upon a time, `process_directives(...)` used to be one monolithic function, with over 400 complicated lines dedicated just to handling directives. Because this was hard to work with, I split the function up considerably, putting most directives' individual functions into a different module; `succ::preprocessor::directives`, which does mean that we jump between files a few times - I'll try to keep it as clear as possible. 

[^7]: Notably, `#ifndef` behaves identically, except with a single boolean inversion at the end.

[^8]: This is done using the `async_recursion` crate, because Rust generally gets unhappy with recursive calls to async functions otherwise.

[^9]: See [the `macroargs` branch](https://github.com/Siri-chan/succ/commits/macroargs/), from commit `314dc8b` onward.

[^10]: The definitions for these are sort of interesting, but I don't know where in this article I would put them, so they are located in [[Supplementaries >> succ#Definitions of Fn Macros]]

[^11]: Thanks to how tables work in markdown, I cannot just use a pipe (`|`) character within a table, even if its within a code block. This is the best I've got.