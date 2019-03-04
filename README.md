![Cake](../gh-pages/Cake.png)

Modules are a powerful Swift feature, yet existing tooling makes modulizing your
projects *so* tedious that most people don’t bother.

A modular app gains:

* **Encapsulation**. Internal scope is a criminally under-utilized Swift feature
    that makes encapsulation significantly more achievable.
* **Namespacing**. Modules have an implicit namespace; fear not about reusing
    names, modulize instead.
* **Hierarchy**. Once you start creating modules you automatically
    arrange them so that some have more importance than others.
    This naturally leads to a *structured* codebase where new files nestle into
    their logical, encapulated homes, *effortlessly*.
* **Organization**. You no longer have to cram everything concerning an area of
    responsibility into a single file to gain from file-private. Instead
    separate all that code out into multiple files in its own module and use
    `internal` access control.
* **Testability**. Making a piece of functionality its own module means you can
    make more of that module internal scope rather than private and this means
    more of the module can be imported `@testable` making the functionality
    easier to test without adopting practices that make your code less readable
    for the sake of testing (like injection).

Cake makes working with Swift modules *a breeze*.

# Xcode 10.2-beta Required

Supporting Swift tools-version-5 and tools-version-4 is not our thing. Cake
requires at least Xcode 10.2 to function.

# Support Cake’s development

Hey there, I’m Max Howell, a prolific producer of open source software and
probably you already use some of it (I created [`brew`]). I work full-time on
open source and it’s hard; currently *I earn less than minimum wage*. Please
help me continue my work, I appreciate it 🙏🏻

<a href="https://www.patreon.com/mxcl">
	<img src="https://c5.patreon.com/external/logo/become_a_patron_button@2x.png" width="160">
</a>

[Other ways to say thanks](http://mxcl.dev/#donate).

[`brew`]: https://brew.sh

# How it works

> “The secret of getting ahead is getting started. The secret of getting started
> is breaking your complex overwhelming tasks into small, manageable tasks, and
> then starting on the first one.” —*Mark Twain*

Cake is an app that runs in your menu bar and watches your Xcode projects. If
you chose to integrate Cake it will automatically generate your module hierarchy
based on your directory structure. For example:

    .
    └ Sources
      └ Model
        ├ Module1
        │ ├ a.swift
        │ └ b.swift
        └ Module2
          ├ c.swift
          └ d.swift

Now **⌘B** and you’ll be able to `import`:

```swift
import Module1
import Module2
```

> **FAQ**: What is a cake project? A Cake project has a `Cakefile.swift` file 
> in its root.

> **Delicious**: All your modules are built *statically* so there’s no
> launch-time consequences and the era of micro-frameworks can truly begin.

> **Curious?** Cake is made with Cake, so is [Workbench], check out the sources
> to see more about what a cake‐project looks like.

> **Details**: Cake generates a sub-project (Cake.xcodeproj), you *lightly*
> integrate this into your app’s project.

[Workbench]: https://github.com/mxcl/Workbench

## Module hierarchies

> “You’ve got to think about the big things while you’re doing small things, so
> that all the small things go in the right direction.” —*Alvin Toffler*

Before long you will need some modules to depend on others. This is an important
step since you are starting to acknowledge the relationships between components
in your codebase. Cake makes declaring dependencies as easy as nesting
directories.

    .
    └ Sources
      └ Model
        └ Base
          ├ a.swift
          ├ b.swift
          └ Foo
            ├ c.swift
            └ d.swift

Here `Foo` depends on `Base` and thus, `Foo` can *now* import `Base`.

*All* other tools require you to specify relationships *cryptically* with either
textually or with a confounding GUI. With Cake, use the filesystem,
relationships are not only easy to read, but also, trivial to refactor (just
move the directory).

> **Further Reading**: [Advanced module hierarchies](Document/Advanced-Module-Hierarchies.md)

> **FAQ**: What should go in your `Base` module? Cake’s `Base` module contains
> extensions on the standard library.

## Dependencies

> “You can do anything, but not everything.” —*David Allen*

Cake makes using Swift packages in Xcode eay. Write out your
[`Cakefile`](Documents/Cakefile.md), **⌘B**, Cake fetches your deps and
integrates them: no muss, no fuss.

```swift
import Cakefile

dependencies = [
    .github("mxcl/Path.swift" ~> 0.8),
    .github("Weebly/OrderedSet" ~> 3),
]

// ^^ naturally using Cake to manage your deps is entirely optional
```

We figure out your deployment targets, we make your deps available to *all* your
targets and we generate a stub module that imports all your deps in one line
(`import Dependencies`).

We check out your dependencies *tidily*, for example the above `Cakefile` gives
you:

    .
    └ Dependencies
      ├ mxcl/Path.swift-0.8.0
      │ ├ Path.swift
      │ └ …
      └ Weebly∕OrderedSet-3.1.0.swift

Which generates to this in your `Cake.xcodeproj`:

<img src='../gh-pages/Screenshot.Deps.png' width='269.5'>

Which you can then commit, *or not commit*: that’s up to you.
[Though we suggest you do](Documents/FAQ.md#should-i-commit-my-deps).

> **Delicious**: All dependency modules are built *statically* so there are no
> launch-time consequences.

> **Delicious**: A fresh clone of a Cake project builds with vanilla Xcode,
> no other tools (even Cake) are required. Distribute away *without* worry!

> **Delicious**: Cake finally makes it possible to use SwiftPM packages for iOS
> development!

> **FAQ**: [Should I commit my deps?](Documents/FAQ.md#should-i-commit-my-deps)

> **Caveat**: We only support SwiftPM dependencies [*at this time*](../../issues/new?title=cocoapods).

> **Further Reading**: [Cakefile Reference]

[more with your Cakefile]: Documents/Cakefile.md

### Op‐Ed—an era for Swift µ-frameworks?

CocoaPods and Carthage libraries tend to be on the *large* side, and this is at
lesat partly because being modular has been historically hard and tedious when
developing for Apple platforms and Swift. SwiftPM encourages smaller, tighter
frameworks and using Cake means making apps with Swift packages is now possible.

Choose small, modular, single‐responsibility libraries with 100% code coverage
that take semantic-versioning **seriously**. Reject bloated libraries that don’t
know how to say no to feature requests.

## Constructing frameworks/dylibs

Since everything Cake builds is a static archive, you can simply link whichever
parts you like into whatever Frameworks or dylibs you need for your final
binaries.

This is a purely optional step, statically linking `Cake.a` into your App (which
Cake sets up by default for you) is perfectly fine. This more advanced option is
available to make apps with extensions more optimal in terms of disk usage and
memory consumption.

# Installation

1. [Download it](../../releases).
2. Run it.
3. Check your menu bar:

    <img src='../gh-pages/Screenshot.Integrate-Cake.png' width='431'>

4. Open a project and integrate Cake; or
5. Create a new Cake.

    <img src='../gh-pages/Screenshot.New-Cake.png' width='431'>

> **FAQ**: [What does integration do?](Documents/FAQ.md#what-does-integration-do)

> **Delicious**: We auto-update!

# Bonus Features

## Extracting Version from Git

Cake determines your App’s version from your git tags, to use them simply
set each target’s “Version” to: `$(SEMANTIC_PROJECT_VERSION)` and if you
like the “Build” number to: `$(CURRENT_PROJECT_VERSION)`.

> *Delicious!* We even append `-debug` to debug builds.

## Xcode Remote Control 

<img src='../gh-pages/Screenshot.Xcode-Menu.png' width='724'>

# Documentation

* Handbook
  * [FAQ](Documents/FAQ.md)
  * [Suggested Usage](Documents/Suggested-Usage.md)
  * [Troubleshooting](Documents/Troubleshooting.md)
* Reference
  * [Cakefile Reference]
  * [Advanced Module Hierarchies](Documents/Advanced-Module-Hierarchies.md)

[Cakefile Reference]: Documents/Cakefile.md
