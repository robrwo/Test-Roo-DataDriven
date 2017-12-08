package Test::Roo::DataDriven;

use v5.10;

use Test::Roo::Role;

use Path::Tiny;
use Ref::Util qw/ is_arrayref /;

use namespace::autoclean;

requires 'run_tests';

use version; our $VERSION = version->declare('v0.0.1');

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

state $eval = sub { eval $_[0] };

sub run_data_tests {
    my ( $class, @args ) = @_;

    my %args =
      ( ( @args == 1 ) && is_hashref( $args[0] ) )
      ? %{ $args[0] }
      : @args;

    my $filter = $args{filter} // sub { $_[0] };

    state $counter = 0;

    $counter++;
    my $package = __PACKAGE__ . "::Sandbox${counter}";

    foreach my $file ( @{ $class->_build_data_files(%args) } ) {

        my $path = $file->absolute;

        note "Data: $file";

        if ( my $data = $eval->("package ${package}; do q{${path}};") ) {

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

                    $class->run_tests( $desc, $filter->($case) );

                }

            }
            else {

                my $desc = $data->{description} // $file->basename;

                $class->run_tests( $desc, $filter->($data) );
            }

        }
        else {

            die "parse failed on $file: $@" if $@;
            die "do failed on $file: $!" unless defined $data;
            die "run failed on $file" unless $data;

        }

    }

}

1;
