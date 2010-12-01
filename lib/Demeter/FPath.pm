package Demeter::FPath;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Moose;
#use MooseX::StrictConstructor;
extends 'Demeter::Path';
use Moose::Util::TypeConstraints;
use Demeter::NumTypes qw( Ipot PosNum PosInt );
use Demeter::StrTypes qw( Empty ElementSymbol );

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use Chemistry::Elements qw(get_symbol get_Z);
use String::Random qw(random_string);

has 'reff'	 => (is => 'rw', isa => 'Num',    default => 0.1,
		     trigger  => sub{ my ($self, $new) = @_; $self->fuzzy($new);} );
has 'fuzzy'	 => (is => 'rw', isa => 'Num',    default => 0.1);
has '+n'	 => (default => 1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'filtered scattering path');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});

#has 'ngrid'	 => (is => 'ro', isa => 'Int',    default => 59);
has 'kgrid'      => (is => 'ro', isa => 'ArrayRef',
		     default => sub{
		       [ 0.000,  0.100,  0.200,  0.300,  0.400,  0.500,  0.600,  0.700, 0.800, 0.900,
			 1.000,  1.100,  1.200,  1.300,  1.400,  1.500,  1.600,  1.700, 1.800,
			 1.900,  2.000,  2.200,  2.400,  2.600,  2.800,  3.000,  3.200, 3.400,
			 3.600,  3.800,  4.000,  4.200,  4.400,  4.600,  4.800,  5.000, 5.200,
			 5.400,  5.600,  5.800,  6.000,  6.500,  7.000,  7.500,  8.000, 8.500,
			 9.000,  9.500, 10.000, 11.000, 12.000, 13.000, 14.000, 15.000,
			16.000, 17.000, 18.000, 19.000, 20.000 ]
		     });
#has 'chi'        => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });

enum('AllElements', [map {ucfirst $_} @Demeter::StrTypes::element_list]);
coerce 'AllElements',
  from 'Str',
  via { get_symbol($_) };
has 'absorber'	   => (is => 'rw', isa => 'AllElements',
		       coerce => 1, default => q{Fe},
		       trigger => sub{ my ($self, $new) = @_;
				       $self->abs_z(get_Z($new));
				     });
has 'scatterer'   => (is => 'rw', isa => 'AllElements',
		      coerce => 1, default => q{O},
		      trigger => sub{ my ($self, $new) = @_;
				      $self->scat_z(get_Z($new));
				    });
has 'abs_z'	 => (is => 'rw', isa => 'Int',    default => 0);
has 'scat_z'	 => (is => 'rw', isa => 'Int',    default => 0);

has 'kmin'	 => (is => 'rw', isa => 'Num',    default =>  0.0);
has 'kmax'	 => (is => 'rw', isa => 'Num',    default => 20.0);
has 'rmin'	 => (is => 'rw', isa => 'Num',    default =>  0.0);
has 'rmax'	 => (is => 'rw', isa => 'Num',    default => 31.0);

## the sp attribute must be set to this FPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  $self->parent($self->fd);
  $self->parent->workspace($self->stash_folder);
  $self->sp($self);
  $self->mo->push_FPath($self);
  $self->put_array('grid', $self->kgrid);
};

override alldone => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->stash_folder, $self->randstring);
  unlink $nnnn if (-e $nnnn);
  $self->remove;
  return $self;
};

override make_name => sub {
  my ($self) = @_;
  $self->name(sprintf("Filtered %s-%s", $self->absorber, $self->scatterer));
};

override set_parent_method => sub {
  1;
  #my ($self, $feff) = @_;
  #$feff ||= $self->parent;
  #return if not $feff;
  #$self->parentgroup($feff->group);
};

after set_datagroup => sub {
  my ($self) = @_;
  if ($self->data->name ne 'default___') {
    $self->kmin($self->data->fft_kmin);
    $self->kmax($self->data->fft_kmax);
    $self->rmin($self->data->bft_rmin);
    $self->rmax($self->data->bft_rmax);
  };
};

sub intrplist {
  q{};
};

sub _filter {
  my ($self) = @_;
  $self->data->_update('fft');
  $self->dispose($self->template('process', 'filtered_filter'));
  return $self;
};

sub _nnnn {
  my ($self) = @_;
  open(my $NNNN, '>', File::Spec->catfile($self->stash_folder, $self->randstring));
  print $NNNN $self->template('process', 'filtered_head');
  my @k   = @{$self->kgrid};
  my @mag = $self->get_array('filtered');
  my @pha = $self->get_array('phase');
  foreach my $i (0 .. $#k) {
    my $mm = ($i==0) ? 0 : $mag[$i];
    printf $NNNN "%7.3f %11.4e %11.4e %11.4e %10.3e %11.4e %11.4e\n", $k[$i], 0.0, $mm, $pha[$i], 1.0, 1e8, $k[$i];
  };
  close $NNNN;
};

override path => sub {
  my ($self) = @_;
  $self->_filter;
  $self->_nnnn;
  $self->_update_from_ScatteringPath;
  $self->label(sprintf("%s-%s path at %s", $self->absorber, $self->scatterer, $self->reff));
  $self->dispose($self->_path_command(1));
  $self->update_path(0);
  return $self;
};

sub pathsdat {
  return q{};
};


1;


=head1 NAME

Demeter::FPath - Filtered paths

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

Build a single scattering path by Fourier filtering  chi(k) data:

  my $fpath = Demeter::FPath->new(data      => $data_object,
                                  name      => "my filtered path",
                                  absorber  => 'Cu',
                                  scatterer => 'O',
                                  reff      => 2.1,
                                  n         => 6,
                                 );
  $fpath -> plot('R');

=head1 DESCRIPTION

This object handles the creation of a path filtered from chi(k) data.
This could be used to create an empirical standard that can be used in
Artemis in the same way as any other Path or Path-like object.  It
could also be used to create a single path-like object from some kind
of theoretical model -- for instance, a histogram created from a
molecular dynamics simulation.

The difference between a Path and FPath is the provenance of the path.
For a Path object, you  must specify either a ScatteringPath object as
the  C<sp>  attribute  or  you  must set  the  C<folder>  and  C<file>
attributes to point at the location of a F<feffNNNN.dat> file.

For an FPath object, you set none of those attributes yourself (they
all get set, but not by you).  Instead, you specify the C<data> from
which the filterted path will be extracted, the C<absorber>,
C<scatterer>, C<reff>, and C<n> attributes, which describe the basic
features of the path being generated.  Demeter will then generate a
single scattering path from the Data object at the approximate
distance in the data. The resulting path will have a natural
degeneracy of 1, which can, of course, be overriden by the C<n>
attribute.

FPath objects are plotted just like any Path object, as shown in the
synopsis above.  They are used in fits in the same way as ordinary
Path objects.  That is, the C<paths> attribute of the Fit object takes
a reference to a list of Path and/or FPath (or other path-like)
objects.

=head1 ATTRIBUTES

As with any Moose object, the attribute names are the name of the
accessor methods.

This extends L<Demeter::Path>.  Along with the standard attributes of
any Demeter object (C<name>, C<plottable>, C<data>, and so on), and of
the Path object, an SSPath has the following:

=over 4

=item C<data>

This takes the reference to the Data object from which the path will
be extracted.

=item C<absorber>

The atomic species of the absorbing atom.  This can be the name
(e.g. copper), the symbol (e.g. Cu), or Z number (e.g. 29).

=item C<scatterer>

The atomic species of the scattering atom.  This can be the name
(e.g. oxygen), the symbol (e.g. O), or Z number (e.g. 8).

=item C<reff>

The approximate path length of the shell being filtered from the data.

=back

=head1 METHODS

There are no outward-looking methods for the FPath object beyond those
inherited from the Path object.  All methods in this module are used
behind the scenes and need never be called by the user.

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Sanity checking, for instance that the data is set before anything is
done, that reff is sensible

=item *

Serialization by itself and in a fit.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

