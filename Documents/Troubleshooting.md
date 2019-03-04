Please note, most of the solutions are: **fully clean and then restart Xcode**.

# Troubleshooting

Xcode builds modules in parallel, it is able to build modules before their
dependencies have finished building to a certain extent. This results in
spurious errors being output during builds that will later disappear. So the
first rule is:

**Let the build finish before reacting to errors that don’t make sense**

Generally it can help to create schemes for Batter or even individual modules in
Batter and build those individually, this will stop Xcode surfacing the wrong
errors, and often, deleting the errors that are actually the root cause. *sigh* 

Xcode 10 seems buggy when it comes to reloading changed projects from disk. If
project navigator is wrong, restart Xcode.

You may get errors in dependent modules when trying to use new API from higher
modules. Xcode doesn’t know about the changes you make in higher modules in the
lower ones until you build. So: `⌘B`.

## Beach-balling

Cake 1.0.0 is not multi-threaded (I know: lol), so give it a bit, it can take
minutes if it is checking out deps.

## Changes are not present in build

Sadly Xcode 10.2 seems to have a bug where static libraries that are themselves 
just accumulations of other static libraries are not always rebuilt. The only
easy solution is cleaning the build :( Or you can open the build folder and
delete `Cake.a` and `Batter.a` and then build.

If this isn’t fixed for 10.2 GM we will build a single Cake.framework instead
which should fix it.

## No syntax highlighting in new files

Xcode 10 regressed many aspects of “blue folder” work. One of which is where
syntax highlighting and completion will sometimes not work in new files.
Restart Xcode.

## No such module 'Foo'

This error is misleading, it actually means a dependency of Foo failed to build.
Look at the other errors Xcode is showing you, at least one will concern a
dependency of Foo, and that is the error you need to tackle.

## “Find selected symbol in workspace” doesn’t work

Xcode only searches within the currently selected scheme, eg. if you want to
search in your iOS app and the macOS app is selected it will only find references
in the macOS codebase. This is an unfortunate “feature” of Xcode.

## No autocomplete when typing `import foo` in Model module

We have no known workaround for this yet, if you have one, please submit. For
now, type it, the import will succeed if the module exists and your dependency
heirarchy is correct.

## New Blue Folders Empty in Xcode 10.x

Xcode 10.x broke blue folders pretty substantially, if you blue folders are
empty but do *actually* contains files, restart Xcode.

## Regeneration doesn’t produce new Batter modules

Xcode 10.x is broken, we *did* regenerate the modules, but Xcode is ignoring the
changes. Fully clean and then restart Xcode.
