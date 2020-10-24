#!/usr/bin/perl -w

use BOSS::Config;
use PerlLib::SwissArmyKnife;

# use Text::Conversation;

$specification = q(
	-t <title>	Title
);

my $config =
  BOSS::Config->new
  (Spec => $specification);
my $conf = $config->CLIConfig;
# $UNIVERSAL::systemdir = "/var/lib/myfrdcsa/codebases/minor/system";

die "Need -t option\n" unless $conf->{'-t'};

my $verbose = 4;

my $title = $conf->{'-t'} || '<REDACTED>';
my $c = read_file("logs/${title}.txt");

my @lines;
my $entry = {};
my $i = 1;
foreach my $line (split /\n/, $c) {
  if ($line =~ /^(\d\d:\d\d:\d\d)\s*(.*?)$/) {
    # wrap up the previous line if exists
    if (scalar @lines) {
      my @linescopy = @lines;
      $entry->{Lines} = \@linescopy;
      my $entrycopy = {};
      foreach my $key (keys %$entry) {
	$entrycopy->{$key} = $entry->{$key};
      }
      $entries->{$i++} = $entrycopy;
      print $i."\n" if $verbose > 3;
      @lines = ();
    }
    my $time = $1;
    my $sender = "unknown";
    my $receiver = "unknown";
    my $restofline = $2;
    if ($restofline =~ /^<([^>]+)>( (.+?))?$/) {
      $sender = $1;
      $restofline = $3;
      # print "<<<$restofline>>>\n";
      if ($restofline =~ /^(\w+)[:,]\b\s*(.*?)$/) {
	$receiver = $1;
	$restofline = $2;
      }
    }
    print 'R: '.$restofline."\n" if $verbose > 3;
    push @lines, $restofline;
    $entry->{Time} = $time;
    $entry->{Sender} = $sender;
    $entry->{Receiver} = $receiver;
  } else {
    $line =~ s/^\s+//sg;
    print 'L: '.$line."\n" if $verbose > 3;
    push @lines, $line;
  }
}
my @linescopy = @lines;
$entry->{Lines} = \@linescopy;
my $entrycopy = {};
foreach my $key (keys %$entry) {
  $entrycopy->{$key} = $entry->{$key};
}
$entries->{$i++} = $entrycopy;
@lines = ();

print Dumper($entries) if $verbose > 3;

if (0) {
  foreach my $key (sort {$a <=> $b} keys %$entries) {
    my $entry = $entries->{$key};
    my $time = $entry->{Time};
    my $sender = $entry->{Sender};
    my $receiver = $entry->{Receiver};
    my $lines = $entry->{Lines};
    next unless $lines;
    my $line = join(' ',@$lines);
    $line =~ s/\.$//sg;
    next unless $sender and $receiver and $time and $line;
    print "<$sender> to <$receiver> at <$time>: $line .\n\n";
  }
}

print Dumper($entries) if $verbose > 3;
foreach my $key (sort {$a <=> $b} keys %$entries) {
  my $entry = $entries->{$key};
  my $time = $entry->{Time};
  my $sender = $entry->{Sender};
  my $receiver = $entry->{Receiver};
  my $lines = $entry->{Lines};
  next unless $lines;
  my $line = join(' ',@$lines);
  $line =~ s/\.$//sg;
  next unless $sender and $receiver and $time and $line;
  my $sentence =  "<$sender> to <$receiver> at <$time>: $line .";
  print ";; $sentence\n";
  print '(#$nluManuallyFormalizedText'."\n";
  print ' (#$sentenceFn "'.shell_quote($sentence)."\")\n";
  print " '())\n\n";
}

