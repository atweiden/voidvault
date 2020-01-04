use v6;

# X::Void::XBPS::IgnoreConfRepos {{{

class X::Void::XBPS::IgnoreConfRepos
{
    also is Exception;

    method message(--> Str:D)
    {
        my Str:D $message =
            'Sorry, `:ignore-conf-repos` must appear alongside `:$repository`';
    }
}

# end X::Void::XBPS::IgnoreConfRepos }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
