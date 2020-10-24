#!/usr/bin/perl -w

use PerlLib::URIExtractor2;

use Data::Dumper;
use String::ShellQuote;

my $command = 'cd ~/.erc/logs && grep -R "<'.shell_quote($ARGV[0]).'>" | grep -E "(f|ht)tps?"';
my $c = `$command`;
my $uris = ExtractURIs($c);
my $seen = {};
my @uris;
foreach my $uri (@$uris) {
  if (! $seen->{$uri}) {
    push @uris, $uri;
    $seen->{$uri} = 1;
  }
}

foreach my $uri (@uris) {
  print "$uri\n";
}
