#!/usr/bin/perl

## Test VPath object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 11;

use Demeter qw(:fit);

my $this = Demeter::VPath -> new();
my $OBJ  = 'VPath';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok($this->plottable,                                    "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
ok( $this->name eq 'virtual path',                      "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( !$this->data,                                       "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

ok( $this->id   eq 'virtual path',                      "id set to its default");
