# Advanced Module Hierarchies

There are some additional rules for hierarchies:

    .
    └ Sources
      └ Model
        ├ foo.swift
        ├ Module1
        │ ├ a.swift
        │ └ b.swift
        └ Module2
          ├ c.swift
          └ d.swift

Here `foo.swift` is part of the “base” module that by default is called
`Bakeware`, all modules depend on the base-module.

    .
    └ Sources
      └ Model
        ├ Module1
        │ ├ a.swift
        │ └ b.swift
        └ Module2
          ├ c.swift
          └ d.swift

Here there is no “base” module. `Module1` cannot not import `Module2`.

    .
    └ Sources
      └ Model
        ├ Module1
        │ ├ a.swift
        │ └ b.swift
        │ └ Module3
        │   ├ c.swift
        │   └ d.swift
        └ Module2
          ├ c.swift
          └ d.swift

`Module3` has a direct dependency on `Module1`, but also depends on (and can
import) `Module1`. A module can always import all of the modules at the level
below it. The direct-dependency is your choice and suggests a closer
relationship.

    .
    └ Sources
      └ Model
        ├ Module1
        │ ├ a.swift
        │ ├ b.swift
        │ └ Module3
        │   ├ c.swift
        │   └ d.swift
        └ Module2
          ├ c.swift
          ├ d.swift
          └ Module4
            ├ c.swift
            └ d.swift

`Module3` **cannot** import `Module4`.

    .
    └ Sources
      └ Model
        └ Module1
          ├ a.swift
          ├ b.swift
          └ Gap
          | └ Module2
          |   ├ c.swift
          |   └ d.swift
          └ Module2
            ├ c.swift
            └ d.swift

Here because of the empty `Gap` folder, `Module2` cannot import `Module1`, but
still depends on `Module1`. Use gaps where you want to insulate some dependency
relationships.
