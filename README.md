em-pg-sequel
===========

[Sequel](http://sequel.rubyforge.org/) adapter for [ruby-em-pg-client](https://github.com/royaltm/ruby-em-pg-client).

Usage
-----

```ruby
require "em-pg-sequel"
EM.synchrony do
  url = "postgres://postgres:postgres@localhost:5432/test"
  db = Sequel.connect(url, pool_class: EM::PG::Sequel::ConnectionPool)

  puts db[:test].all.inspect

  EM.stop
end
```

Right now em-pg-client doesn't support this adapter, you should use [my patched fork](https://github.com/fl00r/ruby-em-pg-client).