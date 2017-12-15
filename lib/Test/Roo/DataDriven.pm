package Test::Roo::DataDriven;

# ABSTRACT: simple data-driven tests with Test::Roo

use v5.10.1;

use Test::Roo::Role;

use curry;
use Path::Tiny;
use Ref::Util qw/ is_arrayref is_hashref /;

use namespace::autoclean;

requires 'run_tests';

our $VERSION = 'v0.2.0';

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This class extends L<Test::Roo> for data-driven tests that are kept in
separate files.

This is useful when a test has hundreds of test cases, where it is
impractical to include all of the cases in a single test script.

This also allows different tests to share the test cases.

=cut

sub _build_data_files {
    my ( $class, %args ) = @_;

    my $match = $args{match} // qr/\.dat$/;

    my @paths = map { path($_) }
      is_arrayref( $args{files} ) ? @{ $args{files} } : ( $args{files} );

    my @files;

    foreach my $path (@paths) {

        die "Path $path does not exist" unless $path->exists;

        if ( $path->is_dir ) {

            my $iter = $path->iterator(
                {
                    recurse         => $args{recurse}         || 0,
                    follow_symlinks => $args{follow_symlinks} || 0,
                }
            );

            while ( my $file = $iter->() ) {
                next unless $file->basename =~ $match;
                push @files, $file;
            }

        }
        else {

            push @files, $path;

        }

    }

    return [ sort @files ];
}

sub _parse_data_file {
    my ( $class, $file ) = @_;

    my $path = $file->absolute;

    state $eval = sub { eval $_[0] };    ## no critic (ProhibitStringyEval)
    state $counter = 0;

    my $package = __PACKAGE__ . "::Sandbox" . $counter++;

    $eval->("package ${package}; do q{${path}};");
}

=for readme stop

=method C<run_data_tests>

This is called as a class method, and is a wrapper around  the C<run_tests>
method.  It takes the following arguments:

=over 4

=item C<files>

This is a path or array reference to a list of paths that contain test
cases.

If a path is a directory, then all test cases in that directory will
be tested.

The files are expected to be executable Perl snippets that return a
hash reference or an array reference of hash references.  The keys
should correspond to the attributes of the L<Test::Roo> class.

See L</DATA FILES> below.

=item C<recurse>

When this is true, then any directories in L</files> will be checked
recursively.

It is false by default.

item C<follow_symlinks>

When this is true, then symlinks in L</files> will be followed.

It is false by default.

=item C<match>

A regular expression to match the names of data files. It defaults to
C<qr/\.dat$/>.

=item C<filter>

This is a reference to a subroutine that takes a single test case as a
hash reference, as well as the data file and case index in that file.

The subroutine is expected to return a hash reference to a test case.

For example, if you wanted to add the data file and index, you might
use

  MyTests->run_data_tests(
    filter = sub {
        my ($test, $file, $index) = @_;
        my %args = (
            %$test,                # avoid side-effects
            data_file  => "$file", # stringify Path::Tiny
            data_index => $index,  # undef if none
        );
        return \%args;
    },
    ...
  );

=item C<parser>

By default, the data files are Perl snippets. If the data files exist
in a different format, then an alternative parser can be used.

For example, if the data files were in JSON format:

  MyTests->run_data_tests(
    match  => qr/\.json$/,
    parser => sub { decode_json( $_[0]->slurp_raw ) },
  );

Added in v0.2.0.

=back

=cut

sub run_data_tests {
    my ( $class, @args ) = @_;

    my %args =
      ( ( @args == 1 ) && is_hashref( $args[0] ) )
      ? %{ $args[0] }
      : @args;

    my $filter = $args{filter} // sub { $_[0] };
    my $parser = $args{parser} // $class->curry::_parse_data_file;

    foreach my $file ( @{ $class->_build_data_files( %args ) } ) {

        note "Data: $file";

        if ( my $data = $parser->($file) ) {

            if ( is_arrayref($data) ) {

                my @cases = @$data;
                my $i     = 1;

                foreach my $case (@cases) {

                    my $desc = sprintf(
                        '%s (%u of %u)',
                        $case->{description} // $file->basename,    #
                        $i++,                                       #
                        scalar(@cases)                              #
                    );

                    $class->run_tests( $desc, $filter->( $case, $file, $i ) );

                }

            }
            elsif ( is_hashref($data) ) {

                my $desc = $data->{description} // $file->basename;

                $class->run_tests( $desc, $filter->( $data, $file ) );
            }
            else {

                die "unsupported data type: " . ref($data);

            }

        }
        else {

            die "parse failed on $file: $@" if $@;
            die "do failed on $file: $!" unless defined $data;
            die "run failed on $file" unless $data;

        }

    }

}

=head1 DATA FILES

The data files are simple Perl scripts that return a hash reference
(or array reference of hash references) of constructor values for the
L<Test::Roo> class..

For example,

  #!/perl

  use Test::Deep;

  +{
    description => 'Sample test',
    params => {
      choices => bag( qw/ first second / ),
      page    => 1,
    },
  };

Notice in the above example, we are using the C<bag> function from
L<Test::Deep>, so we have to import the module into our test case to
ensure that it compiles correctly.

Note that there is no performance loss in repeating module imports in
every test case. However, you may want to use a module like L<ToolSet>
to import common packages.

Data files can contain multiple test cases:

  #!/perl

  use Test::Deep;

  [

    {
      description => 'Sample test',
      params => {
        choices => bag( qw/ first second / ),
        page    => 1,
      },
    },

    {
      description => 'Another test',
      params => {
        choices => bag( qw/ second third / ),
        page    => 2,
      },
    },

  ];

The data files can also include scripts to generate test cases:

  #!/perl

  sub generate_cases {
    ...
  };

  [
    generate_cases( page => 1 ),
    generate_cases( page => 2 ),
  ];

=head1 KNOWN ISSUES

=head2 Skipping test cases

Skipping a test case in your test class, e.g.

  sub BUILD {
    my ($self) = @_;

    ...

    plan skip_all => "Cannot test" if $some_condition;

  }

will stop all remaining tests from running.

=head2 Prerequisite Scanners

Prerequisite scanners used for build tools may not recognise modules
used in the L</DATA FILES>.  To work around this, use the modules as
well in the test class or explicitly add them to the distribution's
metadata.

See L</BUGS> below.

=for readme continue

=head1 SEE ALSO

L<Test::Roo>

=head1 append:AUTHOR

The initial development of this module was sponsored by Science Photo
Library L<https://www.sciencephoto.com>.

=cut

1;
