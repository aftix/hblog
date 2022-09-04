---
title: "Start Using Bevy in Rust"
author: aftix
description: "A look into the start of my development process with Bevy"
draft: true
---

# Finally Making a Game

I started learning programming because of games. My first programs were
mods for Minecraft. Luckily, Java didn't taint me, and I'm still programming
a decade or so later. In that time, I have made a few very rudimentary games.
I have made Conway's game of life, of course (though I am interested in using that for
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
in my opinion, both were complex and over-engineered. I want to make a 3D game, so ggez is out. Bevy it is.

There's another reason I like bevy. It's data-oriented, centered around the entity component system model, or
ECS. ECS engines have entities, which are usually just an integer, to hold data. You attach components to entities
to hold data, and then use systems to act on the systems. By default, systems in Bevy are run every frame. Importantly,
systems in bevy are just normal Rust functions!

## Introduction to ECS

Let's look at how to use Bevy's ECS system. We'll start with an App, which is a
scaffolding to hold our ECS.

```rust
use bevy::prelude::*;

fn main() {
    App::new().run();
}
```

This code snippet is the basis of starting our game. Nothing happens yet! You have to add entities, components,
and systems. Let's add a startup system to say hello:

```rust
use bevy::prelude::*;

fn say_hello() {
    println!("Hello, world!");
}

fn main() {
    App::new().add_system(say_hello).run();
}
```

Run the crate. We have hello world!
 Now, let's add an entity to the world. We'll do that using a startup system
and the `Commands` parameter.

```rust
use bevy::prelude::*;

fn say_hello() {
    println!("Hello, world!")
}

fn setup(mut cmds: Commands) {
   cmds.spawn(); 
}

fn main() {
    App::new().add_system(say_hello).add_startup_system(setup).run();
}
```

There is no noticeable difference in behavior. Let's go ahead and make this entity a
person by adding a component.

```rust
use bevy::prelude::*;

#[derive(Component)]
struct Person {
    name: String,
    age: u8,
}

fn say_hello() {
    println!("Hello, world!")
}

fn setup(mut cmds: Commands) {
   cmds.spawn().insert(Person {
    name: "Bob".to_owned(),
    age: 25,
   }); 
}

fn main() {
    App::new().add_system(say_hello).add_startup_system(setup).run();
}
```

Time to do something with Bob. We can make him say a greeting every frame by adding a query to a system.

```rust
use bevy::prelude::*;

#[derive(Component)]
struct Person {
    name: String,
    age: u8,
}

fn say_hello() {
    println!("Hello, world!")
}

fn setup(mut cmds: Commands) {
   cmds.spawn().insert(Person {
    name: "Bob".to_owned(),
    age: 25,
   }); 
}

fn person_greet(q: Query<&Person>) {
    for person in &q {
        println!("Hi, I'm {} and I'm {} years old.", person.name, person.age);
    }
}

fn main() {
    App::new().add_startup_system(say_hello).add_startup_system(setup).add_system(person_greet).run();
}
```

Finally, let's compartmentalize this. Things other than people can have names, and ages.
Let's break those out into separate components that can be reused and make Person into a marker
component:

```rust
#[derive(Component)]
struct Name(String);
#[derive(Component)]
struct Age(u8);
#[derive(Component)]
struct Person;

fn person_greet(q: Query<(&Name, &Age), With<Person>>) {
    for (name, age) in &q {
        println!("Hi! I'm {} and I'm {} years old.", name.0, age.0);
    }
}

fn setup(mut cmds: Commands) {
   cmds.spawn().insert(Name("Bob".to_owned())).insert(Age(25)).insert(Person);
}
```

Now, any entities can have `Name` and `Age`, but only a `Person` will send a greeting.

## Introduction to Rendering

## Introduction to States

## Main Menu UI

## Generate World Sphere

## Camera control