package Test::Roo::DataDriven;

use v5.10;

use Test::Roo::Role;

use List::Util ();
use Package::Stash;
use Path::Tiny qw/ path /;
use Ref::Util qw/ is_arrayref is_hashref /;

use namespace::autoclean;

sub run_data_tests {
    my ( $class, @args ) = @_;

    my %args =
      ( ( @args == 1 ) && is_hashref( $args[0] ) )
      ? %{ $args[0] }
      : @args;

    $args{match} //= qr/\.dat$/;

    my $order = $args{shuffle} ? \&List::Util::shuffle : sub { sort @_ };

    my @files = map { path($_) }
      is_arrayref( $args{files} ) ? @{ $args{files} } : ( $args{files} );

    foreach my $path ( $order->(@files) ) {

        die "Path $path does not exist" unless $path->exists;

        if ( $path->is_dir ) {

            my $iter = $path->iterator(
                {
                    recurse         => $args{recurse}         || 0,
                    follow_symlinks => $args{follow_symlinks} || 0,
                }
            );

            while ( my $file = $iter->() ) {
                next unless $file->basename =~ $args{match};
                $class->_test_file( $file, %args );
            }

        }
        else {

            $class->_test_file( $path, %args );

        }

    }

}

sub _test_file {
    my ( $class, $file, %args ) = @_;

    my $path = $file->absolute;

    state $counter = 0;

    my $package = sprintf( '%s::Sandbox%04u', __PACKAGE__, ++$counter );
    my $sym     = '$data';
    my $perl    = "package $package;
our $sym = do q{$path};
";

    state $eval = sub {
        eval $_[0];
    };

    if ( $eval->($perl) ) {

        my $stash = Package::Stash->new($package);
        my $data  = ${ $stash->get_symbol($sym) };

        if ( is_arrayref($data) ) {

            foreach my $case (@$data) {
                $class->run_tests($case);
            }

        }
        else {

            $class->run_tests($data);

        }

    }
    else {

        die $@ // $!;

    }

}

1;
