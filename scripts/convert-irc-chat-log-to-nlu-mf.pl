#!/usr/bin/perl -w

use BOSS::Config;
use PerlLib::SwissArmyKnife;

use HTML::Strip;

# use Text::Conversation;

$specification = q(
	-t <title>	Title

	-p		Use Prolog
	-s		Use SubL
);

my $config =
  BOSS::Config->new
  (Spec => $specification);
my $conf = $config->CLIConfig;
# $UNIVERSAL::systemdir = "/var/lib/myfrdcsa/codebases/minor/system";

die "Need -t option\n" unless $conf->{'-t'};

my $verbose = 4;

my $title = $conf->{'-t'} || 'logs/<REDACTED>';
my $c = read_file($title);

my @lines;
my $entry = {};
my $i = 1;
foreach my $line (split /\n/, $c) {
  if ($line =~ /^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d)\s*(.*?)$/) {
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

my $hs = HTML::Strip->new();

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
  my $cleansender = $hs->parse( $sender );
  my $cleanreceiver = $hs->parse( $receiver );
  my $cleanline = $hs->parse( $line );

  if ($conf->{'-s'}) {
    my $sentence =  "<$cleansender> to <$cleanreceiver> at <$time>: $cleanline .";
    my $qsentence =  shell_quote($sentence);

    print ";; $sentence\n";
    print "(#\$nluManuallyFormalizedText\n";
    print " (#\$sentenceFn \"$qsentence\")\n";
    print "  '())\n\n";
  } elsif ($conf->{'-p'}) {
    my $sentence =  "<$cleansender> to <$cleanreceiver> at <$time>: $cleanline .";

    print "%% $sentence\n";
    print "sentence('$title',sentenceIdFn($key),".shell_quote($sentence).").\n";
    print "hasFormalization('$title',sentenceIdFn($key),\n";
    print "                 [\n";
    print "                  _\n";
    print "                 ]).\n\n";
  }
}
