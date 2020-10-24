#!/usr/bin/perl -w

use PerlLib::SwissArmyKnife;

my $data = DeDumperFile('all-uses.dat');

my $seen = {};
foreach my $user (keys %{$data->{AllResults}}) {
  foreach my $pattern (keys %{$data->{AllResults}{$user}}) {
    foreach my $sentence (keys %{$data->{AllResults}{$user}{$pattern}}) {
      foreach my $entry (@{$data->{AllResults}{$user}{$pattern}{$sentence}}) {
	$seen->{$entry}++;
	$entry->{$user}{$pattern}{$sentence}{$entry}++;
      }
    }
  }
}

foreach my $entry (sort {$seen->{$b} <=> $seen->{$a}} keys %$seen) {
  print $seen->{$entry}."\t".$entry."\n";
}
