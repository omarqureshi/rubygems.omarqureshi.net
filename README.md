# rubygems.omarqureshi.net

The site: a **gem feed** and the **API documentation** hosted at
`rubygems.omarqureshi.net`.

It knows nothing about AWS or Kubernetes. Give it a gem name and version from
the feed and it publishes documentation for it — the relationship rubygems.org
has with rubydoc.info.

## What lives here

| | |
| --- | --- |
| `docs-gen/` | turning a Ruby gem into a documentation tree, and this site's look |
| `docs-gen/gen-feed-index.rb` | the gem feed's index page — hosting, not documentation |
| workflows | building doc trees, syncing to S3, invalidating CloudFront |

## What deliberately does not live here

Two doc post-processors stay in
[jsii-target-ruby](https://github.com/omarqureshi/jsii-target-ruby) and are
imported, because they encode decisions the *target* makes about how Ruby is
rendered rather than anything about this site:

- `constantize-static-reads.rb` — a static readonly member reads as
  `Type::NAME` (via `Jsii::StaticConstants`), so the reference must display it
  that way. If the target ever revisits that, this has to change in the same
  commit; separating them is how they drift apart.
- `root_module.rb` — derives a generated tree's root module.

## Open question

The documentation generators need the *assembly*, not just the gem
(`gen-index.rb` and `gen-module-landing.rb` are handed one today). Gems built
by pacmak already ship an assembly tarball in `lib/`, so the site could read it
straight from the gem — except that tarball is the original npm assembly, not
the profile-merged one these generators actually consume. Either the
distribution repositories ship the merged assembly inside their gem (which
makes the gem self-describing and this site trivially dumb), or they hand it
over alongside. Worth settling before the first end-to-end run.
