use v6;
unit grammar Archvault::Grammar;

# match a single lowercase alphanumeric character, or an underscore
token alnum-lower
{
    <+alpha-lower +digit>
}

# match a single lowercase alphabetic character, or an underscore
token alpha-lower
{
    <+lower +[_]>
}

# hostname (machine name)
regex host-name
{
    # translated from: http://stackoverflow.com/a/106223
    ^
    [
        [
            <+:Letter +digit>
            ||
            <+:Letter +digit>
            <+:Letter +digit +[-]>*
            <+:Letter +digit>
        ]
        '.'
    ]*
    [
        <+:Letter +digit>
        ||
        <+:Letter +digit>
        <+:Letter +digit +[-]>*
        <+:Letter +digit>
    ]
    $
}

# linux username validation
regex user-name
{
    # from `man 8 useradd` line 255:
    # - username must be between 1 and 32 characters long
    # - username cannot be 'root'
    # - username must start with a lower case letter or an underscore,
    #   followed by lower case letters, digits, underscores, or
    #   dashes
    # - username may end with a dollar sign
    (
        <alpha-lower> ** 1
        <+alnum-lower +[-]> ** 0..30
        <+alnum-lower +[-] +[$]>?
    )
    { $0 !eq 'root' or fail }
}

# LUKS encrypted volume device mapper name validation
token vault-name
{
    <alpha> ** 1
    <+alnum +[-]> ** 0..15
}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
