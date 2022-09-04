---
title: "Start Using Bevy in Rust"
author: "aftix"
description: "A look into the start of my development process with Bevy"
draft: true
---

# Finally Making a Game

I started learning programming because of games. My first programs were
mods for Minecraft. Luckily, Java didn't taint me, and I'm still programming
a decade or so later. In that time, I have made a few very rudimentary games.
I have made Conway's game of life, of course (thoguh I am interested in using that for
learning compute shaders...) A lot of the time, however, I started making a game then stopped.
Why was that? Simply because I wanted to make a 3D game, and I'd start from scratch with OpenGL
every time (implementing vector math myself, too). I learned and relearned projection matrices and
homogeneous coordinates. I would get a textured cube spinning, with camera controls, and then feel tired
at the slow progress and quit. Writing primarily in C didn't help. This time, I'm reaching for Rust
and Bevy.

## Why Rust

Rust is my favorite programming language. It started as a research language at Mozilla, the makers of
Firefox. There are many things that make Rust unique, but the main one is the use of ownership rules and
borrowing for fearless concurrency. This isn't a blog post about Rust, though, so go read one of those if
you want to learn more.

I particularly like Rust because I feel productive in it. I'm not implementing basic data structures; the
standard library has enough, and if it doesn't then cargo is there to help. I can use modern language features.
Finally, I can multithread my code much more easily than with C.

## Why Bevy

There are many game engines in Rust, none of them mature. Bevy is among the most popular, providing
support for 2D and 3D games. ggez is another popular engine, but it only supports 2D games. There are
two once-popular now forgotten engines, Piston and Amethyst. Both came early into the ecosystem, and,
in my opinion, both were complex and overengineered. I want to make a 3D game, so ggez is out. Bevy it is.

There's another reason I like bevy. It's data-oriented, centered around the entity component system model, or
ECS. ECS engines have entities, which are usually just an integer, to hold data. You attach components to entities
to hold data, and then use systems to act on the systems. By default, systems in Bevy are run every frame.

## Introduction to ECS

## Introduction to States

## Introduction to Rendering

## Main Menu UI

## Generate World Sphere

## Camera control