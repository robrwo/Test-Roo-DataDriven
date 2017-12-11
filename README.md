# NAME

Test::Roo::DataDriven

# SYNOPSIS

    package MyTests

    use Test::Roo;

    use lib 't/lib';

    with qw/
      MyClass::Test::Role
      Test::Roo::DataDriven
      /;

    1;

    package main;

    use Test::More;

    MyTests->run_data_tests(
      files   => 't/data/myclass',
      recurse => 1,
    );

    done_testing;

# DESCRIPTION

This class extends [Test::Roo](https://metacpan.org/pod/Test::Roo) for data-driven tests that are kept in
separate files.

This is useful when a test has hundreds of test cases, where it is
impractical to include all of the cases in a single test script.

This also allows different tests to share the test cases.

# SEE ALSO

[Test::Roo](https://metacpan.org/pod/Test::Roo)

# AUTHOR

Robert Rothenberg <rrwo@cpan.org>

The initial development of this module was sponsored by Science Photo
Library [https://www.sciencephoto.com](https://www.sciencephoto.com).

## Contributors

Aaron Crane <arc@cpan.org>

# LICENSE

This library is free software and may be distributed under the same
terms as perl itself. See l&lt;http://dev.perl.org/licenses/>.
