#!/usr/bin/perl -w

use Capability::Tokenize;
use PerlLib::SwissArmyKnife;
use System::StanfordParser;
use Sayer;

my $debug = 0;
my $overwrite = 0;

my $sayer = Sayer->new
  (
   DBName => "sayer_generic",
   Debug => $debug,
  );

my $stanfordparser =
  System::StanfordParser->new
  (
   Debug => $debug,
   Sayer => $sayer,
  );

my $data = DeDumperFile('all-uses.dat');

my $seen = {};
foreach my $user (keys %{$data->{AllResults}}) {
  foreach my $pattern (keys %{$data->{AllResults}{$user}}) {
    foreach my $sentence (keys %{$data->{AllResults}{$user}{$pattern}}) {
      my @result = Tokenize(Text => $sentence);
      push @tokenized, join(' ',@{$result[0]});
      if (scalar @tokenized >= 3) {
	my $res1 = $stanfordparser->BatchParse
	  (
	   Text => join("\n",@tokenized),
	   Overwrite => $overwrite,
	  );
	print Dumper({Res1 => $res1});
	@tokenized = ();
      }
      # foreach my $entry (@{$data->{AllResults}{$user}{$pattern}{$sentence}}) {
      # 	$seen->{$entry}++;

      # }
    }
  }
}

foreach my $entry (sort {$seen->{$b} <=> $seen->{$a}} keys %$seen) {
  print $seen->{$entry}."\t".$entry."\n";
}
