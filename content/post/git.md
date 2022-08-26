---
title: "Git"
author: "aftix"
description: "Begone, github"
date: 2020-06-18
draft: false
---

# Self-hosted git

Git was made to be decentralized. Why trust
only gitlab or github with your code? It's actually
extremely easy to set up your own git server, assuming
you already have a VPS and domain name.

I set up read/write access to repos on my
VPS using the standard
[git tutorial](https://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server).
Then, I went through my repos and
`git remote set-url origin <my-url>`, adding
github and gitlab remotes as well (so my code will be
mirrored on my [gitlab](https://gitlab.com/aftix) and my
[github](https://github.com/aftix)). To make pushing commits
to all my remotes easy, I added
`alias gua="git remote list | grep -v upstream | xargs -l git push"`
and
`alias gum="git remote list | grep -v upstream | xargs -I _ git push _ master"`
to my `.zshrc` file, allowing me
to push the current branch or the master branch to all my remotes
(except for upstream, which is usually not a repo I have
write access to). To give people the ability to clone my
repos directly from my server, I set up the
[git daemon](https://git-scm.com/book/en/v2/Git-on-the-Server-Git-Daemon)
with systemd. Now, I had read/write access to my repos, and
the entire world can read my repos right from my new
subdomain, git.aftix.xyz with the URL `git://git.aftix.xyz/<repo>.git`.

Now everyone can use my git server as I wanted them to. However,
I also wanted to make my repos explorable in a browser over HTTPS.
There are many solutions to this, such as [cgit](https://git.zx2c4.com/cgit/about/)
and
[git tea](https://gitea.io/). These solutions are a bit much
for me, as git tea has many features I don't need (e.g. user logins
and pull requests), and cgit uses cgi. Since my repos are small,
I chose to serve static project pages via nginx. This matches well
with my blog, which is also serving static pages over nginx.
So, I built and installed [stagit](https://git.2f30.org/stagit/),
which generates static pages from git repos (this is what
[suckless](https://suckless.org) uses to make their git
pages). After creating some git hooks and scripts, I just had
to change the style to be consistent with my blog. I'm pleased
with the results, but I do wish stagit supported javascript plugins
so I could use code syntax highlighting. I could make a shell script
that goes through the html pages and uses sed to insert a script
tag before the closing body tag, but that would probably be
very slow to run. Regardless, my git trees are now browsable at
[https://git.aftix.xyz](https://git.aftix.xyz). The only
thing left to do is to see if I can make the dwm repo show
the `my_dwm` branch instead of `master`.