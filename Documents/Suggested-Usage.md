# Suggested Usage

## 1

`import` precise Batter modules from within Batter modules. In your app
`import Cake`. In Batter import `Dependencies`. This means you are being aware
of the right relative encapsulation when working in the different parts of your
project. Trying to keep all the different levels in mind at all times is a waste
of cognitive load better spent figuring out your actual code.

Being precise in your models means you are acutely aware of your internal
dependency graph.

## 2

Be judicious with modules. This allows you to use internal access control
liberally and have eg. an Error enum per module. If you find yourself needing
more than one error enum, maybe this is a hint that it's time to figure out
where to split this module into two. 

## Precisely specify `import`s

If you are only using a small portion of a module specify that, for 
example, don’t:

```swift
import Foo
```

Instead:

```
import enum Foo.Bar
```

This is instructive to you and others using your code, that this file is
only concerned with a portion of module `Foo`; not its entirety.

If you start importing more and more then switch to `import Foo`, since
you are wasting your reader’s time, and also, you now use the majority
of `Foo`.

Use your judgement: this suggestion is a legibility aid.

## Model Purity

Attempt to keep your model “pure”, that is, do not manipulate global state,
this includes `UserDefaults`, and controlling the implementations of how
input and output occur.

Obviously within reason, it would be a pretty lame database module that
couldn’t persist and fetch data. Apply this suggestion with common sense.

## Xcode navigation

We provide a blue folder for your Model that is the direct directory structure,
with this you can see the module heriarchy.

In the embedded Cake.xcodeproj there is also a flat, topologically sorted module
listing.

Use both (along with `⌘⇧O`) when navigating your module structures.
