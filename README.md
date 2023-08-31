# CoreDataPublisher

Combine Publisher for your Core Data entities.

## Usage

``` swift
import CoreDataPublisher

let fetchRequest = Entity.fetchRequest()
let entities: AnyPublisher<[Entity], Never> = managedObjectContext.publisher(for: fetchRequest)
```

## Installation

You can add CoreDataPublisher to your Xcode project by adding it as dependency.

> https://github.com/Gamec/core-data-publisher

Or you can add it to SPM by editing your `Package.swift` file:

``` swift
dependencies: [
  .package(url: "https://github.com/Gamec/core-data-publisher", from: "0.1.0")
]
```

## License

[MIT license](LICENSE)
