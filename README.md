# fluent-plugin-gree_community

Fluentd input plugin from GREE community.

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-gree_community'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-gree_community

## Usage

    # fluent.conf
    <source>
        type gree_community

        tag gree

        # http://gree.jp/community/{community_id}
        community_id 2397366

        # Regexp for thread title
        thread_title_pattern 雑談|要望
        # Top N threads to watch
        recent_threads_num 4

        # optional, default=true
        # omit output when startup
        silent_startup true

        # Pit ID for GREE account('email' and 'password' required)
        pit_id gree

        # Update interval[sec]
        interval_sec 20
    </source>

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Changes

### 0.0.1(unreleased)

* Initial release.
