---
title: "Bacon"
author: "aftix"
description: "An Overview of Mathematical Methods"
date: 2021-01-05
draft: false
---

# Scientific Computing in Rust

While getting my degree in Physics, I had to take classes in both MatLab and Python
for scientific computing. I preferred python, where we used the SciPy and NumPy
packages. In fact, I used those packages again (along with matplotlib) in an
undergraduate research project simulating bacteria films. There's a catch: I was
also pursuing a degree in Computer Science, and Python just wasn't fast enough
for that side of me, so, during my free time in graduate school, I rewrote my biofilm
simulation in my new favorite language, Rust.

First problem: I needed to replace
`jsonpickle` for data serialization. This problem was easy, as the `serde` crate
is an amazing replacement (I even transitioned from JSON to Rusty Object Notation, RON).
Second problem: Should I try to get matplotlib bindings in Rust or should I use
a more Rust-y plotting library? I decided on the latter, finding `plotters` to be
a suitable replacement for matplotlib. Last problem: How do I replace the differential
equation solvers of SciPy? I ended up writing a custom predictor-corrector solver
which worked well enough, giving identical simulation results while being five
hundred times faster than my python code at just the simulation step, rendering
not included (plotting directly to an RGB buffer then using libx264 bindings to
generate raw H.264 frames that mpv can understand also gave a similar speedup to
the rendering step over writing out every frame as a png file in matplotlib and
using a shell script to ffmpeg the outputs together). Full disclosure, a large part
of this speedup probably comes from my _derivative_ function being not-python, rather
than my implementation of a differential equation solver over SciPy's. Furthermore,
I only breached the five hundred barrier when switching to using a QuadTree to
find the nearest neighbors of a bacteria, before that the speed up was more in
the three hundreds. This port of my old project can be found [here](https://github.com/aftix/rustfilm)
if you care for some reason.

## Introducing bacon-sci

Inspired, I decided to start on a full SciPy replacement in rust as I could not find
one I liked on crates.io (I later found the `peroxide` crate). I even had a clever name:
[bacon](https://github.com/aftix/bacon), named after Francis Bacon and the pork based food; however, `bacon` is already
a crate, so I went for the next best thing: [bacon-sci](https://crates.io/crates/bacon-sci).

I started out with the easiest part. SciPy has a set of scientific constants from
the NIST. I just took the list of important constants from SciPy and put it in a module.
In addition, I took NIST's CODATA and put it into a global map that corresponds a
String of the constant's name to a triplet: an f64 of its value, an f64 of its uncertainty,
and a String of its units. How do you make a static map? I just used the `lazy_static`
crate.

Next, I returned to the area that inspired me: initial value problems. After that,
I tackled root finding and polynomials. Lastly, as of now, I implemented a few special
polynomials and numeric differentiation. Armed with a copy of Burden and Faires's
"Numerical Analysis (8th ed.)", Wikipedia, and SciPy source code, I went to work.

The first decision I made was to use a linear algebra crate, specifically `nalgebra`.
I have written many vector and matrix implementations in the past, and I didn't feel
like doing it this time. Besides, `nalgebra` is probably faster than anything I
can write.

The next decision was using the `alga` crate to handle generics
of complex types and real types. I wanted all algorithms that could work on
complex numbers to be able to, so most of the functions in `bacon-sci` work on
`N: ComplexField`. If an algorithm requires a parameter to be well-ordered (like time),
then it is a `N: RealField`. In cases where a function takes both, the generic parameter
is a `N: ComplexField` with the real parameters being `N::RealField`, which is the real
"backing type" of the possibly complex field. Some functions require complex arithmetic,
so they automatically upgrade from `N: ComplexField` to `Complex<N::RealField>` from
`num_complex`.

Interestingly, there are cases where I wanted to automatically
downgrade from definitely complex back to "maybe complex", which was more difficult
than the other way. To upgrade, all I needed was `Complex::<N::RealField>::new(z.real(), z.imaginary())`,
where `z` is a possibly complex value,
with real types giving zero on the imaginary component. To go the other way, I decided
to basically take the real component and ignore the imaginary component. To do this from
a `N: ComplexField` I had to check if `N::RealField == N` to see if `N` was real
or complex. To do this, I used `TypeId::of::<N::RealField>() == TypeId::of::<N>()`.
If `N` was real, converting from complex was easy: use `ComplexField::from_real` on
the real component, ignoring the imaginary. On the other hand, if `N` was complex,
the conversion needed to preserve the imaginary component. `ComplexField` has no
`from_imaginary`, so I directly implemented !LATEX~ a + bi !LATEX! with
`ComplexField::from_real(z.re) + (-ComplexField::one()).sqrt() * ComplexField::from_real(z.im)`,
with `z` being the definitely complex value.

## Euler Method

A differential equation is an equation describing a thing in terms of how
that thing changes. For those unfamiliar, [this](https://www.youtube.com/watch?v=p_di4Zn4wz4)
is a good introduction. In order to solve a differential equation, you need some conditions.
These come in two flavors: boundary conditions and initial values, with both names
being self-describing. My second task on `bacon-sci` was to implement algorithms
that solve initial value differential equations, referred to as initial value
problems or `ivp` in the code.

Abstractly, the system of differential equations can be written, with an arrow
representing a vector quantity, as
!LATEX \frac{\mathrm{d}\vec{y}}{\mathrm{d}t} = f(t, \vec{y}) . !LATEX!
This is a first-order system of differential equations since
only the first derivative is present. Generally, many higher-order
equations can be reduced to first-order by thinking of each derivative
as a new variable. The initial condition is then represented as
!LATEX \vec{y}(t_0) = \vec{y}_0 !LATEX!

These equations immediately lead to the first algorithm
for solving initial value problems, Euler's method. Consider
this question: given a time-step !LATEX~ \Delta t !LATEX!, what is the
corresponding !LATEX~ \Delta \vec{y} !LATEX!? We can approximate
!LATEX~ \Delta \vec{y} / \Delta t \approx \mathrm{d}\vec{y}/\mathrm{d}t = f(t, \vec{y}) !LATEX!,
(that is, use the tangent line to estimate the function),
leading to !LATEX~ \Delta \vec{y} = f(t, \vec{y} )\Delta t !LATEX!. This gives us an iterative
algorithm, !LATEX~ \vec{y}_{i + 1} = \vec{y}_{i} + f(t, \vec{y})\Delta t !LATEX!. This
is Euler's method. From the starting conditions, pick a time-step and iterate until
you reach the end.

So how good is Euler's method? Not very good. As an example, imagine solving
a mechanics differential equation with positions and velocities. Conservation
of energy says that energy should be conserved. Will Euler's method conserve
energy? In general, it will not. Energy in Euler's method tends to explode.
One solution to this is to use a slightly different version of the algorithm
known as Euler-Cromer or the semi-implicit Euler's method. In this method,
velocities are updated first, then positions are updated using the new velocities
(in Euler's method, you'd use the old velocities). Euler-Cromer is much better,
tending to conserve energy, especially in spring systems. According to Gaffer on Games,
game physics tend to use the Euler-Cromer as it only requires calculating the derivative
once but gives much better results than Euler's.

## Runge-Kutta Methods

One problem with Euler's method is that the error in each step is linear in the
step size. We can do better. To start with, remember Taylor series from
basic calculus. That is, remember you can approximate a function of one
variable like
!LATEX
    f(x) = f(x_0) + f'(x_0) (x - x_0) + \frac{f''(x_0)}{2} {(x - x_0)}^2 + \ldots .
!LATEX!
Similarly, we can approximate our derivative function from the last section with
!LATEX
    f(t, \vec{y}) = f(t_0, \vec{y}_0)
    + \left((t - t_0)\frac{\partial f}{\partial t}(t_0, \vec{y}_0)
    +(\vec{y} - \vec{y}_0)\frac{\partial f}{\partial \vec{y}}(t_0, \vec{y}_0)\right)
    + \ldots ,
!LATEX!
where the powers of our vectors are done element-wise. Additionally, Taylor's Theorem
bounds the error via some small parameters !LATEX~ \xi, \mu!LATEX!.
In this light, we can say Euler's method is a zeroth order approximation, which is
why the error is linear. You can use Taylor polynomials for better IVP solvers, but
this requires information about the derivatives of !LATEX~ f!LATEX!. Instead, Runge-Kutta
methods allow for tighter error bounds without using the derivative.

To see an example of this, I will derive the midpoint method here. Imagine for a
moment that instead of taking a full time-step, you take a partial time-step and use
!LATEX~ f!LATEX! at that point to approximate the second Taylor polynomial. That is, choose
a !LATEX~ a_1, \alpha_1, \beta_1!LATEX! so that !LATEX~ a_1 f(t + \alpha_1, \vec{y} + \beta_1)!LATEX!
approximates
!LATEX
    T^{(2)}(t, \vec{y}) = f(t, \vec{y}) + \frac{h}{2}f'(t, \vec{y}),
!LATEX!
where !LATEX~ h!LATEX! is the time-step, with quadratic error in the time-step.
Note that !LATEX~ f'(t, y) = \partial f/\partial t(t, \vec{y})
+ \partial f/\partial \vec{y}(t, \vec{y}) \vec{y}'(t) !LATEX!.
Thus,
!LATEX
    T^{(2)} = f(t, \vec{y}) + \frac{h}{2}\frac{\partial f}{\partial t}f(t, \vec{y})
    + \frac{h}{2}\frac{\partial f}{\partial \vec{y}}(t, \vec{y}) f(t, \vec{y}) .
!LATEX!
Expanding !LATEX~ a_1 f(t + \alpha_1, \vec{y} + \beta_1)!LATEX! via Taylor series gives
!LATEX
    a_1 f(t, \vec{y}) + a_1 \alpha_1 \frac{\partial f}{\partial t}(t, \vec{y})
    + a_1\beta_1 \frac{\partial f}{\partial y}(t, y) .
!LATEX!
Thus, !LATEX~ a_1 = 1!LATEX!, !LATEX~ a_1 \alpha_1 = h/2!LATEX!, and !LATEX~ a_1 \beta_1 =
f(t, \vec{y}) h / 2!LATEX!. This uniquely determines the coefficients, giving rise to
the midpoint method:
!LATEX
    \vec{y}_{i + 1} = \vec{y}_i + hf\left(t_i + \frac{h}{2}, \vec{y}_i + \frac{h}{2}f\left(t_i, \vec{y}_i\right)\right) .
!LATEX!

This process can be repeated for higher order polynomials. The classic
Runge-Kutta method is order 4, and is used as follows:
!LATEX
    \vec{k}_1 = hf(t_i, \vec{y}_i),
!LATEX!
!LATEX
    \vec{k}_2 = hf\left(t_i + \frac{h}{2}, \vec{y}_i + \frac{1}{2}\vec{k}_1\right),
!LATEX!
!LATEX
    \vec{k}_3 = hf\left(t_i + \frac{h}{2}, \vec{y}_i + \frac{1}{2}\vec{k}_2\right),
!LATEX!
!LATEX
    \vec{k}_4 = hf(t_i + h, \vec{y}_i + \vec{k}_3),
!LATEX!
!LATEX
    \vec{y}_{i+1} = \vec{y}_i + \frac{1}{6}(\vec{k}_1 + 2\vec{k}_2 + 2\vec{k}_3 + \vec{k}_4).
!LATEX!
This is almost what is in `bacon-sci`. Note that Runge-Kutta methods can be described
by a table of the coefficients of !LATEX~ h!LATEX! when added to !LATEX~ t_i!LATEX! for the various
intermediate steps, the coefficients of each previous intermediate step for an intermediate step,
and the final weighted average coefficients.

## Adam-Bashforth Methods

There's a problem with all the IVP solvers discussed
so far. The algorithm may take steps between two solution
points, but it never remembers those steps. In other words,
we throw away a lot of useful information. Multistep
methods solve this problem by retaining information about
previous steps. In an equation, you can characterize
an !LATEX~ m!LATEX! step method as
!LATEX
    \vec{y}_{i+1} = \sum_{j=0}^{m-1} a_{m-1-j}\vec{y}_{i-j} +
    h\sum_{j=0}^{m} b_j f(t_{i+1-m + j}).
!LATEX!
Notice that some methods can have a point depend on the derivative at that point. These
are implicit methods.

Adam-Bashforth methods are explicit methods that use Newton's backward difference formula
to find the coefficients. `bacon-sci` _almost_ implements a fifth order Adams-Bashforth
method.

## Adaptive Step Size Methods

Still, all of these methods have a problem. The step size, !LATEX~ h!LATEX!, is
the same for complicated interesting parts of the solution and
boring flat parts! Ideally, the step size will be small in the complex
bits and large in the flat bits to minimize computation time. Enter
adaptive step size methods!

The main idea of adaptive step sizes is to have two estimates
of the next step, one more accurate and one less accurate. Let
the norm of the difference between the two be the error.
If the error is small, then increase the step size. If the error
is large, try the step again with a smaller step size. A simple
algorithm for any of the above solvers is to solve the next step twice,
once with the full step size and once with half the step size. Then, if the error
is too small, double the step size. If the error is too big, half the step size.
This algorithm works, but is computationally expensive, and smaller
step sizes may produce worse results due to round-off error. Better methods exist.

A good way to estimate error for Runge-Kutta methods is to use two orders of
methods, taking the value from the higher order method. The classic example of this
is the Runge-Kutta-Fehlberg method, which uses an order 4 and order 5 method. The
best part about this technique is that the fourth and fifth order methods share
some intermediate steps, so only 6 intermediate steps need to be found!

For the multistep solvers, a good strategy is to make a prediction
of the next step using an explicit method. Then, take the prediction
and use it in an implicit method of the same order. These techniques are known
as predictor-corrector methods.

Finally, I can talk about the implementation of `bacon-sci`. In my crate, I have a
`trait IVPSolver` that defines everything I want an IVP solver to be. I have one direct
implementation, `Euler`. On top of that, I have a `struct AdamsInfo` and `struct RKInfo` that
implement `IVPSolver` for general predictor-corrector methods and adaptive runge-kutta methods
respectively. Then, I have traits `RungeKuttaSolver` and `AdamsSolver` that specify
which coefficients are needed and how to interact with `RKInfo` and `AdamsInfo`. I have
specified the Runge-Kutta-Fehlberg method and a fifth order predictor-corrector method
within `bacon-sci` for the end user. They are built using builder functions after a `new` call.

Why do I need the `*Info` structs? Why can't I just `impl<T: RungeKuttaSolver> IVPSolver for T`,
so runge-kutta implementors only need to define the coefficients? Well, doing that wildcard
implementation conflicts with `Euler`. Rust isn't smart enough to know that since
my crate has control over both `Euler` and `RungeKuttaSolver`, downstream crates
can not possible implement `RungeKuttaSolver` for `Euler`. Furthermore, the wildcard
implementations would conflict on possible downstream types implementing `RungeKuttaSolver`
and `AdamsSolver`.

What else is there for `bacon-sci`? Well, there exist methods known an backwards differentiation
formulas which are very useful for differential equations the aforementioned methods
fail at; however, they are implicit methods. How does one solve an implicit equation?
Well, stay tuned!

## Solving Initial Value Problems with `bacon-sci`

The theory is all well and good, but how do you solve an initial value
problem with `bacon-sci`? There are currently seven implemented solvers in
the library: `RK45`, `RK23`, `Adams`, `Adams2`, `BDF`, `BDF2`, and `Euler`. As mentioned
previously, `IVPSolver` is a trait, so all of these solvers have a shared interface. For this
example, I'll solve a one-dimensional problem with !LATEX~ y(0) = 0!LATEX! using `RK45`. The derivative
function (that is, !LATEX~ f(t, y)!LATEX! is of the form: `fn deriv<T>(t: f64, y: &[f64], params: &mut T) -> Result<VectorN<f64, U1>, String> { ... }`.
Here, I am using `f64` for both `t` and `y`, but `f32` would work as well (you can even
have `y` be a `Complex<{float}>` type with `t` being the corresponding real
float type). In this case, you'd solve the initial value problem in a manner
such as:
```rust
fn solve() -> Result<(), String> {
    let mut rk = RK45::new()
        .with_dt_min(0.01)?
        .with_dt_max(0.1)?
        .with_tolerance(1e-3)?
        .with_start(0.0)?
        .with_end(1.0)?
        .with_initial_conditions(&[1.0])?
        .build();
    let path = rk.solve_ivp(deriv, &mut ());

    Ok(())
}
```

`bacon-sci` also has a general-purpose function `solve_ivp` which tries
to solve an initial value problem with a fourth-order Adams predictor-corrector,
then the Runge-Kutta-Fehlberg method, and finally with adaptive BDF6. This is the
function you'll probably want to use.

## Root finding

After initial value problems, the next area of numerical analysis I tackled
is root finding. What is root finding? It's finding the solutions of
!LATEXf(x) = 0, !LATEX!
for an arbitrary function. In other words, you are finding where a function
becomes zero. There's a related problem of finding stationary points, that is
the solutions of
!LATEXf(x) = x,!LATEX!
for an arbitrary function. Problems can be easily translated between the two
domains; however, in `bacon-sci` I have only implemented algorithms for the first
problem, root finding.

What are the algorithms `bacon-sci` has? I have currently implemented the bisection
method, Newton's method, the secant method, and Müller's method for polynomials.

## Bisection Method

The bisection method is the easiest to understand. It requires two starting points,
!LATEX~ a!LATEX! and !LATEX~ b!LATEX!, such that the sign of !LATEX~ f(a)!LATEX! and the sign of !LATEX~ f(b)!LATEX!
are different (if one is zero then you found a root!). Then, the algorithm
performs a binary search, dividing the interval !LATEX~ [a,b]!LATEX! in half. At the midpoint,
the sign of the function is either zero, meaning success, the same as at !LATEX~ a!LATEX! or
the same as at !LATEX~ b!LATEX!. Thusly, you either get a result or have one new interval
with differing signs at the end points. This is done recursively until an answer
is found.

What are the problems with this method? Firstly, you need two starting points with
differing signs. Next, this only works with single dimensional real numbers. Other
algorithms described here work with complex vector functions. On the bright side,
the initial two guesses can be any distance from a root of the function without
the algorithm failing. I should note here that there's a closely related algorithm
called the method of false position. In this algorithm, instead of the midpoint,
you choose the dividing line between two subintervals to be where the line
from !LATEX~ f(a)!LATEX! to !LATEX~ f(b)!LATEX! crosses the x axis.

The bisection method is implemented as `bacon_sci::roots::bisection`.

## Newton's Method

Newton's method is a more sophisticated method of root finding. To derive it,
first assume that !LATEX~ f!LATEX! is continuous and doubly differentiable on
!LATEX~ [a,b]!LATEX!. Now, give a starting guess for the root, !LATEX~ p_0!LATEX!. Then,
we can expand !LATEX~ f!LATEX! as a Taylor series centered at !LATEX~ p_0!LATEX!:
!LATEX
    f(p) = f(p_0) + (p - p_0)f'(p_0) + \ldots .
!LATEX!
Ignoring the higher order terms,
!LATEX
    f(p) = f(p_0) + (p - p_0)f'(p_0) .
!LATEX!
Now, let !LATEX~ p!LATEX! be the true root of the function. Thus,
!LATEX
    0 = f(p_0) + (p - p_0)f'(p_0) ,
!LATEX!
!LATEX
    0 = f(p_0) + pf'(p_0) - p_0f'(p_0),
!LATEX!
!LATEX
    pf'(p_0) = p_0 f'(p_0) - f(p_0),
!LATEX!
!LATEX
    p = p_0 - \frac{f(p_0)}{f'(p_0)}.
!LATEX!
Since we ignored higher order terms, this is only an
approximation of the true root !LATEX~ p!LATEX!. However,
this is a better approximation than the starting one!

Iterating this equation over and over again until the guess produces a zero of the
function is Newton's method. What are the problems with it? Firstly, there's the
obvious problem that you need the derivative of the function, which may not be
available. Secondly, the procedure fails if the derivative is ever zero. Thirdly,
the process fails if the initial guess is far from a root (Taylor series need only be
accurate around the point of expansion).

Newton's method is implemented as `bacon_sci::roots::newton`, with a specialized
version for polynomials as `bacon_sci::roots::newton_polynomial`.

## Secant Method

The secant method is an adaptation of Newton's method to remove the need
for an explicit derivative. To derive it, imagine calculating !LATEX~ p_{n+1}!LATEX!, the
!LATEX~ n+1!LATEX!th iteration of Newton's method. You would need the derivative at
!LATEX~ p_n!LATEX!, but the derivative at that point is just the slope of the tangent line
at that point! This can be approximated by a _secant line_ from the point and a
nearby point. Luckily, we have a nearby point: !LATEX~ p_{n-1}!LATEX!. Thus,
!LATEX
    f'(p_n) \approx \frac{f(p_n) - f(p_{n-1})}{p_n - p_{n-1}} .
!LATEX!
Putting this into Newton's method,
!LATEX
    p_{n+1} = p_n + \frac{f(p_n)(p_n - p_{n-1})}{f(p_n) - f(p_{n-1})} .
!LATEX!
This is the secant method.

The secant method has an obvious advantage over Newton's method. It also has
an obvious trade-off: you need two starting points instead of one. There is also
a trade-off that the secant method shares with Newton's method: the roots aren't
bracketed. What does this mean? In the bisection method, we always had an interval
within which there was sure to be a root. The root we were approaching always
was within this interval. The successive iterations of Newton's method and
the secant method do not bracket a root like this. There is a second method of
false position which modifies the secant method to be bracketed, but `bacon-sci`
does not implement either version.

The secant method is implemented as `bacon_sci::roots::secant`.

## Müller's Method

Müller's method is related to the secant method. While the secant method
uses a line to approximate the derivative, Müller's method uses a parabola. Currently,
`bacon-sci` only implements Müller's method for polynomials.

This concludes a tour of the root finding available in `bacon-sci`. I think these methods
are rather out of date, especially for polynomial root finding. In the case of polynomials,
I solve for linear and quadratic roots exactly, but all higher order polynomials of
order use something called Laguerre's method. It's a specialized method that pretty
much always returns a root of a polynomial, no matter the initial guess, so I
start with an initial guess of zero and find a root. Then, I divide out the
root from the polynomial and find another root. So on and so forth. This dividing
process is known as deflation. Then, going up the recursion tree, I use Newton's
method to remove some error introduced by floating points in that the root of the
lower order polynomials may not exactly match the roots of the higher polynomials.

Müller's method for polynomials is implemented as
`bacon_sci::roots::muller_polynomial`.

## Polynomials

If you've made it this far, I assume you know what polynomials are. `bacon-sci`
provides a `struct Polynomial<N: ComplexField>` for polynomials. How do I represent
them? In the most straightforward way: a list of coefficients. In this form, adding
and subtracting polynomials is easy. Furthermore, it makes it simple to do polynomial
long division, which is always slow. Finally, it allows for a way to evaluate
polynomials at a value that is more numerically stable than the straight forward way.
This evaluation method is known as Horner's method or synthetic division. Consider
!LATEX
    P(x) = a + bx + cx^2 + dx^3 .
!LATEX!
You can evaluate it in this order:
!LATEX
    P(x) = a + x \cdot (b + x\cdot (c + x\cdot (d))) .
!LATEX!
That is Horner's method, It only requires !LATEX~ n!LATEX! additions and multiplications,
where !LATEX~ n!LATEX! is the order of the polynomial. As a bonus, it is numerically
more stable. Let !LATEX~ b_k = a_k + b_{k+1}x_0!LATEX! for !LATEX~ k = n-1,n-2,\ldots, 0!LATEX!
with !LATEX~ b_n = a_n!LATEX! (!LATEX~ a_k!LATEX! is the !LATEX~ k!LATEX!th coefficient of the polynomial).
This is just formalizing Horner's method at !LATEX~ x_0!LATEX!: every !LATEX~ b!LATEX! is a step in the process.
This means that !LATEX~ b_0 = P(x_0)!LATEX!. Now, if you make a polynomial
!LATEX
    Q(x) = b_n x^{n-1} + b_{n-1} x^{n-2} + \ldots + b_1 ,
!LATEX!
then
!LATEX
    P(x) = (x - x_0)Q(x) + b_0 .
!LATEX!
This is where the name synthetic division comes from: you are dividing a
polynomial by a linear factor and getting a quotient and a remainder.

Notice what differentiating does to this expression:
!LATEX
    P'(x) = Q(x) + (x - x_0)Q'(x),
!LATEX!
so
!LATEX
    P'(x_0) = Q(x_0).
!LATEX!
This allows an optimization: the derivative and polynomial value
at a point can be computed at the same time, first getting the
!LATEX~ b_k!LATEX! then performing Horner's method on these to evaluate
!LATEX~ Q!LATEX! in the same loop. This makes Newton's method for polynomials
especially efficient.

So you've seen the benefits of the coefficient representation. What are the
downsides? Well, it can be much bigger than factored representations. Think about
!LATEX~ {(x + 2)}^{100}!LATEX! in coefficient form. Another downside is that naive multiplication
is !LATEX~ O(n^2)!LATEX!, assuming we're multiplying two polynomials of order !LATEX~ n!LATEX!. We can
do better. Enter the point form of polynomials. You may know this, but !LATEX~ n!LATEX! points
on a polynomial completely determines the polynomial, assuming the polynomial degree
is bounded to !LATEX~ n!LATEX!. Thus, you can represent a polynomial of degree bound !LATEX~ n!LATEX!
by its evaluation at !LATEX~ n!LATEX! preset points, !LATEX~ x_k!LATEX!. To multiply in point form,
we have !LATEX~ C(x) = A(x)B(x) \implies C(x_k) = A(x_k)B(x_k)!LATEX!. This is
!LATEX~ O(n)!LATEX!!

So, a better algorithm for multiplying two order !LATEX~ n!LATEX! polynomials is to
change them to point form of order !LATEX~ 2n!LATEX! (the maximum order their product
can be), do the !LATEX~ O(n)!LATEX! multiplication, then convert back. Sadly, to evaluate
!LATEX~ n!LATEX! points with Horner's method, which is !LATEX~ O(n)!LATEX!, is !LATEX~ O(n^2)!LATEX!. Luckily,
one can choose special points to evaluate the polynomial at: the !LATEX~ nth!LATEX! roots
of unity. What are those? They are the solutions to the equation !LATEX~ \omega^n = 1!LATEX!.
For example, the second roots of unity are !LATEX~ \pm 1!LATEX!, and the fourth are
!LATEX~ \pm 1,\pm i!LATEX!. These roots of unity have cyclic properties that makes them
useful as points. Using [Euler's formula](https://en.wikipedia.org/wiki/Euler%27s_formula),
the roots of unity can easily be calculated. Furthermore, they can be entirely
generated in a sequence from a "first" root of unity. Other circle-y properties
give rise to the fast Fourier transform algorithm. Technically, this algorithm
computes a discrete Fourier transform; however, it can be used to transform
the coefficient representation to the point representation in !LATEX~ O(n \log n)!LATEX! time.
Thus, we get !LATEX~ O(n \log n)!LATEX! polynomial multiplication! `bacon-sci` uses the classic
fft algorithm which requires the order to be a power of two, so I pad the coefficient
representation to the nearest power of two that is larger than !LATEX~ 2n!LATEX!. Thus,
the multiplication requires a tolerance to get rid of leading zeros in the
result. I store this tolerance within the polynomial. As a caveat, the roots of
unity are complex by nature, so I do the automatic "upgrading" process from
a possibly complex type to a complex type I mentioned earlier for the fft, and I do
the "downgrading" process mentioned earlier for the reverse fft. Finally, I special
cased multiplying by a constant polynomial or a linear polynomial to be !LATEX~ O(n)!LATEX!.
This is because these operations are common in other algorithms and thus must be
fast.

## Special Polynomials

I wanted some special functions in `bacon-sci`. For the first pass, I just have some special
polynomials.

To get to why these polynomials are special, we have to talk about the inner product.
We can define a inner products between two functions from a set of functions in relation
to a weighting function !LATEX~ w(x)!LATEX! on an interval !LATEX~ [a,b]!LATEX! with
!LATEX
    {\langle f, g\rangle}_w = \int_a^b f(x) g(x) w(x) \,\mathrm{d} x .
!LATEX!
!LATEX~ a!LATEX! can be !LATEX~ -\infty!LATEX!, !LATEX~ b!LATEX! can be !LATEX~ \infty!LATEX!, but the inner product
between all functions in your set must be finite. Two functions are _orthogonal_
if their inner product is zero. This concept is a generalization of the dot product.
The dot product is
!LATEX
    \vec{v} \cdot \vec{w} = \sum_n v_n w_n .
!LATEX!
Since functions have a continuum basis, the sum becomes an integral. Furthermore,
we can throw in a weight function because the integral will still follow the rules
from the dot product with it in there (think about how you can define norms in
space not using the regular Pythagorean formula, like the taxi cab norm).

Classic orthogonal polynomials are sets of polynomials defined as orthogonal in this
sense. Every polynomial in the set must have a different degree, and every degree
must be present. Thus, the polynomials from the set can be labeled with a subscript
of their degree. Any two different polynomials from the set must be orthogonal with
relation to the weighting function on a specified interval. These orthogonal
polynomials are the complete orthogonal basis (but not necessarily orthonormal) for
the space of functions on some definite interval.

The first set of orthogonal polynomials are the Legendre polynomials. For this set,
the weighting function is !LATEX~ w(x) = 1!LATEX! and the interval is !LATEX~ [-1,1]!LATEX!. They can
be defined with:
!LATEX
    P_0 = 1,
!LATEX!
!LATEX
    P_1 = x,
!LATEX!
!LATEX
    (n+1)P_{n+1} = (2n+1) x P_n - n P_{n-1} .
!LATEX!

The next set of orthogonal polynomials are the Hermite polynomials. For this set,
the interval is !LATEX~ (-\infty,\infty)!LATEX!, for which the most natural weighting function
is !LATEX~ \exp(-x^2)!LATEX!. There are actually two versions of Hermite polynomials. `bacon-sci` implements
the so-called physicist's Hermite polynomials instead of the statistician's Hermite
polynomials. The kind implemented here can be defined with:
!LATEX
    H_0 = 1,
!LATEX!
!LATEX
    H_1 = 2x,
!LATEX!
!LATEX
    H_{n+1} = 2 x H_n - 2n H_{n-1} .
!LATEX!

The third set of orthogonal polynomials are the Laguerre polynomials. These are orthogonal
on the interval !LATEX~ [0,\infty)!LATEX! with the most natural weighting function
!LATEX~ \exp(-x)!LATEX!. Unlike the previous two, Laguerre polynomials can be found without
a recurrence relation:
!LATEX
    L_n = \sum_{k=0}^{n} \binom{n}{k} \frac{{(-1)}^k}{k!}x^k .
!LATEX!

Finally, `bacon-sci` currently also implements Chebyshev polynomials, which are polynomials
relating to trigonometric functions. Consider !LATEX~ \cos n\theta!LATEX!. This can be expanded
into a polynomial of !LATEX~ \cos \theta!LATEX!. Replace !LATEX~ \cos \theta!LATEX! with !LATEX~ x!LATEX! and
you have the !LATEX~ n!LATEX!th degree Chebyshev polynomial of the first kind. These polynomials
have the recurrence relation
!LATEX
    T_0 = 1,
!LATEX!
!LATEX
    T_1 = x,
!LATEX!
!LATEX
    T_{n+1} = 2x T_n - T_{n-1} .
!LATEX!
Likewise, you can expand !LATEX~ \sin n\theta!LATEX! as !LATEX~ \sin \theta!LATEX! times a
polynomial term in !LATEX~ \cos \theta!LATEX!. Take that polynomial term and replace
!LATEX~ \cos \theta!LATEX! with !LATEX~ x!LATEX! to get Chebyshev polynomials of the second kind,
also defined by the recurrence relation
!LATEX
    U_0 = 1,
!LATEX!
!LATEX
    U_1 = 2x,
!LATEX!
!LATEX
    U_{n+1} = 2x U_n - U_{n-1} .
!LATEX!
Both kinds of Chebyshev polynomials are orthogonal polynomials on !LATEX~ [-1,1]!LATEX!. The
first kind polynomials have weight !LATEX~ 1/\sqrt{1 - x^2}!LATEX! and the second
kind polynomials have weight !LATEX~ \sqrt{1 - x^2}!LATEX!.

All of these special polynomials can be found under
`bacon-sci::special`.

## Polynomial Interpolation

Sometimes, you want to define a function that passes through a set of points. A
convenient class of functions to use are, of course, polynomials. The first problem
of polynomial interpolation is then this: Given a list of points, find a polynomial
that passes through all the points. This problem is analogous to approximating a function
by taking several point values and interpolating with a polynomial.

The first polynomial that may come to mind is a Taylor series, but these series are
actually not very good at this task. Taylor series concentrate their accuracy on
a single point, so they can only be relied on for approximating a function at values
close to that point. This does not jive with our problem statement. Instead, we use
what are known as Lagrange polynomials. To understand these, consider the case where
we have 2 points: !LATEX~ (x_0, y_0)!LATEX! and !LATEX~ (x_1, y_1)!LATEX! of some function !LATEX~ f!LATEX!.
Then, define
!LATEX
L_0(x) = \frac{x - x_1}{x_0 - x_1}
!LATEX!
and
!LATEX
L_1(x) = \frac{x - x_0}{x_1 - x_0} .
!LATEX!
Now, we can define a polynomial
!LATEX
P(x) = L_0 (x) y_0 + L_(x) y_1 .
!LATEX!
Notice that !LATEX~ L_0(x_0) = 1!LATEX!, !LATEX~ L_0(x_1) = 0!LATEX!,
!LATEX~ L_1(x_0) = 0!LATEX!, and !LATEX~ L_1(x_1) = 1!LATEX!.
Thus, !LATEX~ P(x_0) = y_0!LATEX! and !LATEX~ P(x_1) = y_1!LATEX!, exactly
as desired. !LATEX~ P!LATEX! is the unique linear interpolation of the
function for these points! This is an order two Lagrange
interpolation. In general, to interpolate with a polynomial of
degree !LATEX~ n!LATEX!,
!LATEX
    L_{n,k} = \frac{(x - x_0) \ldots (x - x_{k-1})(x - x_{k+1})\ldots (x - x_n)}
    {(x_k - x_0) \ldots (x_k - x_{k - 1})(x_k - x_{k+1}) \ldots (x_k - x_n)},
!LATEX!
or
!LATEX
    L_{n,k} = \prod_{i \neq k}^{n} \frac{x - x_i}{x_k - x_i} .
!LATEX!
Then, the Lagrange interpolating polynomial is
!LATEX
    P(x) = \sum_{i=0}^{n} y_i L_{n,i}(x) .
!LATEX!

There is a slight problem implementing the above definition in code: a lot of work
needs to be redone. An order !LATEX~ n!LATEX! interpolating polynomial can be built up
gradually from lower orders by taking different points at a time. This work can
be cached in a table to avoid re-doing things. Calculating the polynomial in this
way is known as Neville's method and is what `bacon-sci` does.

Now, what if you have more information about !LATEX~ f!LATEX!? For example, what if you have
the derivative at all of your points as well? This is a generalization of Lagrange
interpolation. For the case the first derivatives are known, the interpolating
polynomial is called the Hermite interpolating polynomial. `bacon-sci` implements this,
but it has stability issues for a large number of points, which isn't surprising.
Think about high-order polynomials: they tend to oscillate a lot. This is similar
to high-frequency oscillation in Fourier transforms, and it limits the usefulness
of polynomial interpolation.

To get around high oscillation polynomials, we can define a _piecewise_ interpolation
of the function with a lower-order polynomial. Cubic polynomials are low order and
they have four unknowns, which is enough to ensure continuity of the interpolation,
smoothness (continuity of the derivatives), and end point behavior. Thus, we call
the piecewise cubic interpolation of a function a cubic spline. There are two
types of cubic splines, free and clamped. Free cubic splines are subject to the
constraint that the endpoints have a second derivative of zero. Clamped cubic splines
are subject to the constraint that the derivative at the endpoints match the function
derivatives. Generally, a clamped cubic spline is more accurate. `bacon-sci` provides
both types of interpolation.

Polynomial interpolation, including cubic spline interpolation,
are implemented under `bacon_sci::interp`.

## Numerical Differentiation

Sometimes, we want to numerically find a derivative of a function. Taking a look
at the definition of a derivative,
!LATEX
    f'(x_0) = \lim_{h \rightarrow 0} \frac{f(x_0 + h) - f(x_0)}{h},
!LATEX!
there is a simple solution: just pick some small !LATEX~ h!LATEX!; however, this approach
is not good because subtracting two close values is prone to round off error. Instead,
we can estimate the derivative by doing Lagrange interpolation on several points. Using
four interpolating points, we can get the so-called five point formula:
!LATEX
    f'(x_0) \approx \frac{1}{12h} \left(f(x_0 - 2h)  -8f(x_0 - h) + 8f(x_0 + h) - f(x_0 + 2h) \right) .
!LATEX!
We can also do higher derivatives this way. For example,
!LATEX
    f''(x_0) \approx \frac{1}{h^2} \left(f(x_0 - h) - 2f(x_0) + f(x_0 + h)\right)
!LATEX!

Numerical differentiation is implemented under
`bacon_sci::differentiate`.

## Numerical Integration

Sometimes, you want to integrate functions numerically. This is called numeric quadrature
due to historical reasons. Technically, you could use the fundamental theorem of calculus
and turn integration problems into differential equation problems, but integrals
are a special case of differential equation, so you should use specialized algorithms.

To start off with, take a function like so:

![function](/imgs/function.png)

To find the area under the curve, there are some simple solutions. Two easy ones are
the right- and left-rectangle rules:

![right-rectangle rule](/imgs/right_rectangle.png)

![left-rectangle rule](/imgs/left_rectangle.png)

Mathematically, this becomes
!LATEX
    \int_a^b f(x)\,\mathrm{d}x \approx (b - a)f(b)
!LATEX!
and
!LATEX
    \int_a^b f(x)\,\mathrm{d}x \approx (b - a)f(a) .
!LATEX!

A better approach is to use the trapezoidal rule:

![trapezoidal rule](/imgs/trapezoid.png)

Mathematically, this is
!LATEX
    \int_a^b f(x)\,\mathrm{d}x \approx \frac{b - a}{2}\left(f(a) + f(b)\right) .
!LATEX!
There is also Simpson's rule, which uses an approximating parabola instead.

An easy way to improve accuracy is to break the interval up into smaller subintervals, turning
a rule into a composite rule like so:

![composite trapezoidal rule](/imgs/composite_trapezoid.png)

Mathematically, the composite trapezoidal rule is with step size !LATEX~ h!LATEX! is:
!LATEX
    \int_a^b f(x)\,\mathrm{d}x \approx \frac{h}{2}\left(f(a) + f(b)\right) + h\sum_1^{n-1} f(a + nh) .
!LATEX!
This takes the form because each intermediate step is part of two trapezoids, the left
trapezoid and the right trapezoid, canceling out the half.
This rule is easily interleaved to use in adaptive quadrature. To half the step size,
you can half the current integral value and then add in points half way between each
of the current points multiplied by the halved step size.

Another approach to adaptive quadrature is to use Simpson's rule. The range can be split
into two, using Simpson's rule on both the full range and each half. If the desired
error is not met, each side of the range can be further subdivided. This concentrates
calculations on the interesting bits of the integrand. `bacon-sci` has a function
implementing this adaptive Simpson's rule.

Generally, Simpson's rule is better than the trapezoidal rule; however, it turns out
that the trapezoidal rule is particularly good when the integrand decays double
exponentially towards the end points (that is, decays as fast as
!LATEX~ \exp(\exp(x))!LATEX!). Taking advantage of this, we can do a variable
substitution to integrate over the interval !LATEX~ [-1, 1]!LATEX! (Any two-sided closed interval
can be changed to this one using another simple change of variable). A good change
of variable to choose is
!LATEX
    x = \tanh\left(\frac{\pi}{2}\sinh t\right),
!LATEX!
using [hyperbolic trig functions](https://en.wikipedia.org/wiki/Hyperbolic_functions).
This changes the interval to !LATEX~ (-\infty, \infty)!LATEX!, pushing the end points out,
so this gives an integration technique not sensitive to end point behavior. In the
future, `bacon-sci` could use this to make integration functions where one or both
endpoints have a singularity in the integrand.
This change of variable changes the integral to
!LATEX
\int_{-1}^1 f(x)\,\mathrm{d}x \approx \sum_{-\infty}^\infty w_k f(x_k),
!LATEX!
where
!LATEX
    x_k = \tanh\left(\frac{\pi}{2}\sinh kh \right)
!LATEX!
and
!LATEX
    w_k = \frac{\frac{h}{2}\pi \cosh kh}{\cosh^2\left(\frac{\pi}{2}\sinh kh\right)} .
!LATEX!
This evaluates the transformed integral using the trapezoidal rule. Since the decay
is double exponential, the limits on the sum can be made finite without much loss of
precision. In `bacon-sci`, the sum is done from -3 to 3, which is correct within
!LATEX~ 1 \times 10^{-12}!LATEX!.  For example, the transformed function from before looks like:

![tanh-sinh integration](/imgs/tanhsinh.png)

This method is called Tanh-Sinh integration. The weights and evaluation
points are precomputed and stored in a lookup table. The trapezoidal rule is
interlaced to compute the integral to a given precision. `bacon-sci` takes its
implementation of Tanh-Sinh integration specifically from the `quadrature` crate,
with attribution (`quadrature` is BSD licensed).

Tanh-Sinh quadrature is implemented as `bacon_sci::integrate::integrate`. Adaptive
Simpson's rule is `bacon_sci::integrate::integrate_simpson`. There is a fixed
integration technique called Romberg integration implemented as
`bacon_sci::integrate::integrate_fixed`.

## Gaussian Integration

In the previous section, all of the integration rules used equally-spaced points.
What if you could choose points spaced optimally for the integrand? Well,
Gaussian integration does just that: it optimally spaces points so that the
highest degree polynomial possible as an integrand is perfectly calculated.

Much like the section on special polynomials, Gaussian integration rules
are determined by an interval and a weighting function. In general, the question
is, what are the optimal points to evaluate to numerically integrate:
!LATEX
    \int_a^b f(x) w(x) \,\mathrm{d}x ?
!LATEX!
As it turns out, the optimal !LATEX~ n!LATEX! points are the zeros of the !LATEX~ nth!LATEX! classical
orthogonal polynomial on the interval !LATEX~ [a,b]!LATEX! with weighting function
!LATEX~ w(x)!LATEX! as defined in the Special Polynomials section.

For general purpose integrals, the best interval is, like in Tanh-Sinh quadrature,
!LATEX~ [-1,1]!LATEX!. This becomes Gaussian-Legendre quadrature. You can also integrate over
!LATEX~ [0,\infty)!LATEX! with Gaussian-Laguerre quadrature and
!LATEX~ (-\infty,\infty)!LATEX! with Gaussian-Hermite quadrature using the most natural
weighting functions. In addition, `bacon-sci` provides both kinds of Chebyshev-Guassian
quadrature. All of these integration functions can be done within a specified tolerance.
Furthermore, all of the weighting function and polynomial zero evaluations are done
ahead of time and stored in a table at compile-time. This is cool, but the best
general purpose integration scheme is still Tanh-Sinh quadrature.

All Gaussian integration techniques discussed here are implemented under
`bacon_sci::integrate`.

## What's Next?

There is much more to be added to `bacon-sci`. For example, many special functions
can be added. Integration can be extended to integrate with end point singularities.
Furthermore, I want to add statistics to `bacon-sci`. Distributions are already covered
by `rand_distr`, but PDFs and CDFs can be added, as well as descriptive
statistics. The next chapter in my numerical analysis book is optimization, so data fitting
to a model using least-squares regression is to come. Lastly, of course, is optimizing
what is currently in use. My integration functions are already fast, and my initial
value problem solvers have benchmarked to be faster than both `peroxide` and `SciPy`. Maybe
I'll have a follow up blog comparing performance.
