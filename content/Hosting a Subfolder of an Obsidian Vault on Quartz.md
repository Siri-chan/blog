---
tags:
  - meta
aliases:
  - How I set this blog up.
description: I go on a journey while putting this blogsite together.
publish: 2024-05-06
---

# Introduction
As you may have noticed, this site is a bit of a hodge-podge. I don't do enough interesting things to blog full time, and the interesting things I do tend to be long-term projects, so it really wasn't worth my time to reinvent the wheel and design a framework for a blog from scratch. Equally, I didn't really want to use some closed-source website like [Blogger](https://www.blogger.com) or deal with the headache of adapting a crusty old Wordpress template to suit my needs - so I procrastinated, wrote a single article in Obsidian, and then went dark for a year, as I presumed I'd never get around to actually publishing anything.

Then, a couple of days ago (at the time of writing), [Yupiel](https://github.com/yupiel) was working on a project that I had previously deemed to likely be infeasible. He was taking a log of his process in Obsidian as well, and then shared it to me through a Quartz instance hosted on Github Pages [^1].  Not only did it remind me that I had written half of a blog article on [[How I built a C preprocessor, how you can too, and why you shouldn't.|my WIP C Compiler, succ]], but it also got me thinking about if I could make my blog a real thing, now that I knew properly publishing markdown was possible. 

It wasn't without some difficulty though...

Before I explain this next part, I need to provide some context:
I have three monolithic Obsidian Vaults that I use for everything; one for University, one for Work, and one for my personal things. The blog article I had written was in a `blog/` subfolder of my personal vault, and while I could have moved it out, it would have somewhat broken the monolithic nature of my huge vaults, with everything interconnected. 

Quartz is designed to host a whole Obsidian vault, and Yupiel had issues even doing that[^2]. However, I needed to use quartz to host a *subfolder* of my Obsidian Vault, and this turned out to be quite the headache.

# The Process
## Bootstrapping

The first steps were the same as any other Quartz instance:
```sh ln=false
$ mkdir ~/code/blog
$ cd ~/code/blog
$ git clone https://github.com/jackyzha0/quartz.git .
Cloning into '.'...
remote: Enumerating objects: 8819, done.
remote: Counting objects: 100% (15/15), done.
remote: Compressing objects: 100% (12/12), done.
remote: Total 8819 (delta 7), reused 8 (delta 3), pack-reused 8804
Receiving objects: 100% (8819/8819), 6.70 MiB | 3.04 MiB/s, done.
Resolving deltas: 100% (5498/5498), done.
$ pnpm i --no-fund
added 514 packages, and audited 516 packages in 10s

1 moderate severity vulnerability

To address all issues, run:
  npm audit fix

Run `npm audit` for details.
$ pnpm run quartz create

> @jackyzha0/quartz@4.2.3 quartz /home/siri/dev/blog
> ./quartz/bootstrap-cli.mjs "create"


┌   Quartz v4.2.3
│
◇  Choose how to initialize the content in `/home/siri/dev/blog/content`
│  Empty Quartz
│
◇  Choose how Quartz should resolve links in your content. This should match Obsidian's link format. You can change this later in
`quartz.config.ts`.
│  Treat links as shortest path
│
└  You're all set! Not sure what to do next? Try:
  • Customizing Quartz a bit more by editing `quartz.config.ts`
  • Running `npx quartz build --serve` to preview your Quartz locally
  • Hosting your Quartz online (see: https://quartz.jzhao.xyz/hosting)
```

Then, I made my first mistake. 
```sh ln=false
$ pwd
/home/siri/code/blog
$ rm -rf content
$ # Note - I didn't do this in the install step even though I could have.
$ # Also note: bootstrap-cli literally says "don't do this unless you know what you're doing" lmao oops
$ ln -s /home/siri/notes/blog /home/siri/code/blog/content
```
## Path Resolution Pains
This symbolic link was the start of my issues. Unlike in a normal Quartz instance, all of my wikilinks looked like `[[blog/Page Title]]`, where Quartz expected them to not have the leading directory. I couldn't even easily change this, as changing these values would fuck up the backlinks when writing the blog posts in Obsidian.
At this point I was already considering just migrating my blog to it's own vault, just to make my life easier - but I reluctantly cracked open the Quartz codebase now living on my system, to see if there was an easy solution.
While `quartz/util/path.ts` initially looked promising, I didn't really find any luck.
It turned out to actually be an easy fix -  the `CrawlLinks` plugin has the `prettyLinks` option, which when combined with `shortest` name resolution does actually fix my issue.

## Minor Modifications
The next thing was fixing the style and layout for better parity with Obsidian, and to better fit my taste. 
Here are the issues  I faced, and the changes I made.
1. Obsidian uses non-standard line breaks. 
	Fortunately, Quartz actually just has a `Plugin.HardLineBreaks()` transformer plugin, which solves this issue.
2. IMO, IBM Plex Mono is an ugly typeface.
	This was as easy as setting `config.configuration.theme.typography.code` to a more pleasant font. In this case, JetBrains Mono.
	I also had to go font browsing, for body and heading fonts that look good with the `ja_JP` locale.
	(*Many fonts just fallback to an ugly OS-default when faced with* 漢字)
	I ended up being a bit indecisive on the header font, as the font I initially picked was a bit too stylized for my taste, and also being too small (without messing with a lot of CSS), but I almost settled on Aoboshi One, after trying several other typefaces, but eventually gave up and just used Noto Sans.
	For the body though, M PLUS was an obvious choice.
	While JetBrains Mono doesn't support Japanese characters, I doubt I will use many (if any) in code blocks in the future, so I hope this will just be fine.
3. Github's Syntax Highlighting colors are vague and don't fit anything well.
	This was another value I could conveniently just configure, and modify the plugin to the *much* nicer Catpuccin (specifically, Mocha and Frappe for light and dark themes, respectively).
4. The theming is not very consistent with my websites of the past.
	This involved yet more styling, mostly of the colors. These were easy enough to yoink from my old CSS, but the process still sucked. 
5. The default layout is missing some elements that I would argue are critical.
	This was actally a rather complicated problem to solve. It turned out that my blog was missing elements, because my laptop's default zoom level makes Quartz think that it is a mobile device. This could easily be solved by zooming out with `Ctrl -` to 90% scale, which fixed this. However, I did end up adding [[index#^76f73a|a disclaimer]] to my `index.md` to hopefully make people at least aware of the issue. I was also going to file an issue on Github, but #[[https://github.com/jackyzha0/quartz/issues/455|455]] already describes this problem. 

My next step was to tidy up the default layout to better fit my preferences - I wanted to put the `Graph` and `Backlinks` components into the footer, just leaving the `TableOfContents` on the right, but attempting to do so made Quartz really unhappy:
->**\[**[[Supplementaries >> Quartz#A Truly Awful Error Message|Message Moved for Article Readability]]**\]**<-
**Holy shit.** 
Well, for better or worse, it turns out that you can't have multiple elements in the footer.[^3] 
While I could have made my own custom footer component, that sounded like a lot of work, so I just decided to put the graph down the bottom, and to leave the backlinks where they were, on the right.
The graph view required some gnarly CSS to get it centered and looking okay, but I eventually got it to a servicable state:
```diff ln=false
diff --git a/quartz/components/styles/graph.scss b/quartz/components/styles/graph.scss
index 3deaa1f..6c44f9e 100644
--- a/quartz/components/styles/graph.scss
+++ b/quartz/components/styles/graph.scss
@@ -1,9 +1,15 @@
 @use "../../styles/variables.scss" as *;

 .graph {
+  margin-top: 20px;
+  border-radius: 5%;
+  background-color: var(--lightgray);
+  width: 50%;
+  margin: auto;
+
   & > h3 {
-    font-size: 1rem;
-    margin: 0;
+    font-size: 1.5rem;
+    text-align: center;
   }

   & > .graph-outer {	
```
# Github Pages
My next challenge was deploying this to Github Pages. Shouldn't be hard, just create a new repo and replace the other upstream.
Only one problem: 
> Git does not store the content of a path referenced by a symlink.

This was doing to be an issue, but not quite yet. Let's set up the repo first:
```sh ln=false
$ git remote set-url origin git@github.com:Siri-chan/blog.git
```

So, I wrote a script:
###### commit.fish
```sh ln=false
#!/usr/bin/env fish
set CONTENT_DIR $(readlink content)
rm content && cp -r $CONTENT_DIR content 
git add . && git commit 
rm -rf content && ln -sr $CONTENT_DIR content
```
This script moves the content directory out of its symlink, commits, and then removes it again.
The big chain of `&&` is necessary as a failsafe in case any of the operations fail.
This behavior seems similar to how `quartz sync` works, but I trust my own code more, if I'm honest.
Now, I just had to test it.
```sh ln=false
$ chmod a+x ./commit.fish
$ ./commit.fish
hint: Waiting for your editor to close the file...
(re.sonny.Commit:261405): [Editor Output Omitted]
[v4 ddbf4d5] Test of `commit.fish`
 10 files changed, 817 insertions(+), 23 deletions(-)
 create mode 100755 commit.fish
 delete mode 100644 content/.gitkeep
 create mode 100644 content/Hosting a Subfolder of an Obsidian Vault on Quartz.md
 create mode 100644 content/How I built a C compiler, how you can too, and why you shouldn't..md
 create mode 100644 content/Supplementary/Supplementaries >> Quartz.md
 create mode 100644 content/index.md
 $ git checkout -b publish
 $ git push --set-upstream origin publish                    12.9s  Mon 06 May 2024 02:15:06 PM AEST
Enumerating objects: 8760, done.
Counting objects: 100% (8760/8760), done.
Delta compression using up to 16 threads
Compressing objects: 100% (3201/3201), done.
Writing objects: 100% (8760/8760), 6.62 MiB | 1.98 MiB/s, done.
Total 8760 (delta 5494), reused 8702 (delta 5452), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (5494/5494), done.
To github.com:Siri-chan/blog.git
 * [new branch]      publish -> publish
branch 'publish' set up to track 'origin/publish'.
```
Looking on Github, everything worked!
Now, we can just whip up a `deploy.yaml` as per [the docs](https://quartz.jzhao.xyz/hosting), and then things should be live, and sure enough, they are. 

## Line Numbers
As I was writing a couple more things, I decided that I really should disable line numbers for code blocks that I didn't want them for. [Rehype](https://rehype-pretty.pages.dev/#line-numbers) doesn't provide any documentation on how to hide them, so I was on my own.
First I tried various modification of the attributes: `hideLineNumbers`, `showLineNumbers{null}` and so on, but to no avail.
I eventually gave up and started digging through Quartz's CSS again. by commening out line 384 of `base.scss`:
```scss ln=384
content: counter(line); 
```

I was able to disable them entirely. While it would be nice to selectively decide for some blocks to have line numbers, line numbers can also cloud the meaning of a block if they are present where they shouldn't be - so I disabled them all.
I didn't disable them within the Obsidian plugin I use for code blocks (since that would fuck with a lot of personal notes), and so the line number metadata is in each codeblock with the `ln=`syntax, for my own reference. Maybe at some stage I will patch Quartz to conditionally show line numbers, or even to use the `ln=` syntax, but that is a challenge for another day.
# Conclusion
This was a weird article to write, especially doing something kinda #meta as my first real post, but I really thought that documenting this journey would be a good exercise to start finishing posts. I also thought that it would have been simpler than it ended up being, since I had some hope that everything would just work, with some tweaks to the default configuration.
That hope was unfounded, and this article became a behemoth of it's own as a result.

I do hope at least that you enjoyed reading about this process, and that you learned a thing or two along the way.

Until you see me again,
	**Siri.**

[^1]: Here's [the log](https://yupiel.github.io/thoughts/projects/PD2-Heister's-Haptics) he sent.
[^2]: Nothing major, just issues with hard line-breaks, and syncing his vault with GitHub separately from the Quartz repo.
[^3]: `footer` is a `QuartzComponent`, rather than a `QuartzComponent[]` like the other layout positions.