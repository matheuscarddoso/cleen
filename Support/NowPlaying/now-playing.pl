# Loads Cleen's Now Playing library and calls one function in it.
# usage: perl now-playing.pl <library.dylib> <cleen_stream|cleen_send>
use strict;
use warnings;
use DynaLoader;

my ($library, $function) = @ARGV;
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error();
my $symbol = DynaLoader::dl_find_symbol($handle, $function) or die "missing $function";
DynaLoader::dl_install_xsub("main::entry", $symbol);
entry();
