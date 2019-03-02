# FAQ

## What does integration do?

Not much.

* We create a `.cake` directory and a `Cakefile.swift` (you can delete that if
    you don’t want Cake to manage your dependencies) in your project directory.
* It adds a “blue folder” in your Xcode project for your Model.
* It adds a reference to `.cake/Cake.xcodeproj` in your Xcode project.
* It makes your application-target link to `Cake.a` and depend on the `Cake`
    target.
* We add a few entries to your `.gitignore`

## How do I deintegrate Cake?

1. Delete `.cake`
2. Delete `Cakefile.swift`
3. Remove the `Cake.xcodeproj` reference from your project
4. Remove the `Model` blue-folder from your project
5. Remove the entries about Cake in your `.gitignore`

## What should I commit?

We recommend committing `.cake` and `Dependencies`. This way anyone can
check out your project and build your app, and they **don’t** need
Cake.app to do so.

Specifically ignore:

`.cake/*.json`

Developers working on your project will benefit from having Cake.app
installed, but it *isn’t required*. Working on your project without
Cake.app means they will not get any of Cake’s automagical features, eg.
buildable model generation.

If you don’t want to commit anything that is generated then add `.cake` to your
`.gitignore`. 

> Though this means you are also ignoring `.cake/Package.resolved` which
is your dependency-pin-file, without this co-workers may have different versions
of their dependencies to you which can make debugging issues harder. Note
open a PR to allow configuration of the location of this file in `Cakefile.swift`.

## Should I commit my deps?

Yeah, you should.

Because your dependencies came from the Internet, and the Internet is not a
consistent or stable place. There is no guarantee your deps will exist next
week, tomorrow or even five seconds from now.

We should never forget [leftpad].

Also, committing your deps *guarantees* everyone on your team is using the same
codebase and not some subtely different set of dependencies.

And committing your deps means people can clone your project and build it
without needing any other tools.

[leftpad]: https://arstechnica.com/information-technology/2016/03/rage-quit-coder-unpublished-17-lines-of-javascript-and-broke-the-internet/

## I don’t want to use Cake for dependencies

It’s not mandatory. If you don’t specify dependencies in your `Cakefile`
everything works fine and there any ugly build artifacts are either deleted or
never created. You could even delete your `Cakefile`.

## Why can modules import ancestors?

What we mean is, for the following:

    .
    ├─ Foo 
    │   ├─ Bar
    │   └─ Baz
    └─ Faz

Foo can `import Bar`. Strictly this does not work for a clean build, Xcode will
fail to find the module in that case.

This happens because the modules are all built to the same directory so they
can see each other.

We should be able to fix this and [plan to](../../issues/13).

## What Swift version is used for compiling modules?

It is extracted from your base project. Dependencies specify their own Swift
versions.

## How do I stay up‐to‐date?

Follow [mxcl](https://twitter.com/mxcl) on Twitter, he strictly only tweets
about Cake, Swift and Open Source.

## Can I make dependencies “editable”?

Yes, this is a SwiftPM feature and since we use SwiftPM for dependency
mangement, it’s the same:

```bash
swift package --package-path .cake --build-path .cake/swift-pm edit foo
```

You will need to force a manual regeneration, ([this is a bug](../../issues/new?title=editable-deps)) but
after that you will be able to edit the package in Xcode.

Make sure you push your changes and make a pull-request!
