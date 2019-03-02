# The Cakefile

Your Cakefile defines your dependencies, and some other properties of your
generated project.

## The `import`

You need the `import`:

```swift
import Cakefile
```

## Dependencies

```swift
dependencies = [
    .github("mxcl/Path.swift" ~> 0.9),
    .git("https://mygit.place/repo" == 2.4)
]
```

If you need more specific version specifications, this is possible:

```swift
let branch = "fix-remote-target-dependency"
var xcodeproj = GitHubPackageSpecification(user: "mxcl", repo: "xcodeproj", constraint: .ref(.branch(branch)))

dependencies.append(xcodeproj)

let foo = PackageSpecification(url: "https://mygit.place/repo", constraint: .ref(.branch("foo")))

dependencies.append(foo)
```

## Options

We provide some options that change the project generation properties:

```swift
options.baseModuleName = "Bakeware"
```

The `baseModuleName` is the name of the root module in your model.

```swift
options.suppressDependencyWarnings = true
```

This will suppress all warnings in your dependencies, it defaults to `true`
since you have no easy control over them.
