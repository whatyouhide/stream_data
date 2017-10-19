# StreamData

[![Build Status](https://travis-ci.org/whatyouhide/stream_data.svg?branch=master)](https://travis-ci.org/whatyouhide/stream_data)
[![Hex.pm](https://img.shields.io/hexpm/v/stream_data.svg)](https://hex.pm/packages/stream_data)

> StreamData is an Elixir library for **data generation** and **property-based testing**.

*Note*: StreamData is in beta. It's a candidate to be included in Elixir itself at some point (but it's not guaranteed to).

## Installation

Add `stream_data` to your list of dependencies:

```elixir
defp deps() do
  [{:stream_data, "~> 0.1", only: :test}]
end
```

and run `mix deps.get`. StreamData is usually added only to the `:test` environment since it's used in tests and test data generation.

## Usage

[The documentation is available online.](https://hexdocs.pm/stream_data/)

StreamData is made of two main components: data generation and property-based testing. The `StreamData` module provides tools to work with data generation. The `ExUnitProperties` module takes care of the property-based testing functionality.

### Data generation

All data generation functionality is provided in the `StreamData` module. `StreamData` provides "generators" and functions to combine those generators and create new ones. Since generators implement the `Enumerable` protocol, it's easy to use them as infinite streams of data:

```elixir
StreamData.integer() |> Stream.map(&abs/1) |> Enum.take(3)
#=> [1, 0, 2]
```

`StreamData` provides all the necessary tools to create arbitrarily complex custom generators:

```elixir
require ExUnitProperties

domains = [
  "gmail.com",
  "hotmail.com",
  "yahoo.com",
]

email_generator =
  ExUnitProperties.gen all name <- StreamData.string(:alphanumeric),
                           name != "",
                           domain <- StreamData.member_of(domains) do
    name <> "@" <> domain
  end

Enum.take(StreamData.resize(email_generator, 20), 2)
#=> ["efsT6Px@hotmail.com", "swEowmk7mW0VmkJDF@yahoo.com"]
```

### Property testing

Property testing aims at randomizing test data in order to make tests more robust. Instead of writing a bunch of inputs and expected outputs by hand, with property-based testing we write a *property* of our code that should hold for a set of data, and then we generated data in this set to verify that property. To generate this data, we can use the above-mentioned `StreamData` module.

```elixir
use ExUnitProperties

property "bin1 <> bin2 always starts with bin1" do
  check all bin1 <- binary(),
            bin2 <- binary() do
    assert String.starts_with?(bin1 <> bin2, bin1)
  end
end
```

To know more about property-based testing, read the `ExUnitProperties` documentation. Another great resource about property-based testing in Erlang (but with most ideas that apply to Elixir as well) is Fred Hebert's website [propertesting.com](http://propertesting.com).

The property-based testing side of this library is heavily inspired by the [original QuickCheck paper](http://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf) (which targeted Haskell) as well as Clojure's take on property-based testing, [test.check](https://github.com/clojure/test.check).

## License

Copyright 2017 Andrea Leopardi and José Valim

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
