#!/usr/bin/perl -w

use KBS2::ImportExport;
use PerlLib::SwissArmyKnife;

my $aptcache = {};
foreach my $line (split /\n/, `apt-cache search .`) {
  if ($line =~ /^(.*?) - (.*)$/) {
    $aptcache->{$1} = 1;
  }
}

my $data = DeDumperFile('all-uses.dat');

my $replacements =
  {
   like => '#$likesObject',
   use => '#$usesProgram',
   using => '#$usesProgram',
  };

my @assertions;
my $entries = {};
my $seen = {};
foreach my $user (keys %{$data->{AllResults}}) {
  foreach my $pattern (keys %{$data->{AllResults}{$user}}) {
    foreach my $sentence (keys %{$data->{AllResults}{$user}{$pattern}}) {
      foreach my $entry (@{$data->{AllResults}{$user}{$pattern}{$sentence}}) {
	if ($aptcache->{$entry}) {
	  $seen->{$entry}++;
	  $entries->{$user}{$pattern}{$sentence}{$entry}++;
	  my $verb = $replacements->{[split /\s/, $pattern]->[-1]};
	  push @assertions, ['a',[$verb, ['#$personHavingIRCAliasFn',Quote($user)], ['#$softwareFn',Quote($entry)]],'#$IRCKBMt'];
	  push @assertions, ['a',['#$evidenceOf', [$verb, ['#$personHavingIRCAliasFn',Quote($user)], ['#$softwareFn',Quote($entry)]], ['#$sentenceFn',Quote($sentence)]], '#$IRCKBMt'];
	} # (a '(#$resultIsa #$SubLFunctionFn #$SubLFunction) #$FRDCSASubLMt)
      }
    }
  }
}

my $importexport = KBS2::ImportExport->new();
my $res1 = $importexport->Convert
  (
   Input => \@assertions,
   InputType => 'Interlingua',
   OutputType => 'CycL String',
  );

if ($res1->{Success}) {
  print $res1->{Output};
}

sub Quote {
  return '"'.$_[0].'"';
}
