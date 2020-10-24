#!/usr/bin/perl -w

use BOSS::Config;
use PerlLib::SwissArmyKnife;

use Lingua::EN::Tagger;
use Try::Tiny;

# use Text::Conversation;

$specification = q(
);

my $config =
  BOSS::Config->new
  (Spec => $specification);
my $conf = $config->CLIConfig;
# $UNIVERSAL::systemdir = "/var/lib/myfrdcsa/codebases/minor/system";

my $verbose = 1;

my $allresults = {};
my $logdir = $ENV{HOME}.'/.erc/logs';
my $i = 0;
foreach my $file (split /\n/, `ls $logdir`) {
  print STDERR "<$file>\n";
  Process(File => ConcatDir($logdir,$file));
  ++$i;
  if (0) {
    if ($i > 100) {
      last;
    }
  }
}
print Dumper({AllResults => $allresults});

sub Process {
  my (%args) = @_;
  my $title = $args{File};
  $title =~ s/[^a-zA-Z0-9]/_/sg;
  my $c = read_file($args{File});
  my @lines;
  my $entries = {};
  my $entry = {};
  my $i = 1;
  foreach my $line (split /\n/, $c) {
    if ($line =~ /^(\d\d(\d\d)?[:-]\d\d[:-]\d\d( \d\d:\d\d:\d\d)?)( \*\*\*)?\s+?(.*?)$/) {
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
      my $restofline = $5;
      if ($restofline =~ /^<([^>]+)>( (.+?))?$/) {
	$sender = $1;
	$restofline = $3 || '';
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

  if (1) {
    print Dumper($entries) if $verbose > 3;
    my $systems = {};
    foreach my $key (sort {$a <=> $b} keys %$entries) {
      my $entry = $entries->{$key};
      my $time = $entry->{Time};
      my $sender = $entry->{Sender};
      my $receiver = $entry->{Receiver};
      my $lines = $entry->{Lines};
      next unless $lines;
      my $line = join(' ',map {$_ || ' '} @$lines);
      $line =~ s/\.$//sg;
      next unless $sender and $receiver and $time and $line;
      my $jlines = join(" ",map {$_ || ' '} @$lines);
      # print $jlines."\n";
      if ($jlines =~ /I use (\S+)/s) {
	push @{$systems->{$sender}{'I use'}}, $jlines;
      }
      if ($jlines =~ /I am using (\S+)/s) {
	push @{$systems->{$sender}{'I am using'}}, $jlines;
      }
      if ($jlines =~ /I like (\S+)/s) {
	push @{$systems->{$sender}{'I like'}}, $jlines;
      }
    }
    # print Dumper($systems);
    ExtractNamedEntities(Systems => $systems);
  }
}

sub ExtractNamedEntities {
  my (%args) = @_;
  my $p = new Lingua::EN::Tagger;
  my $newresults = {};
  foreach my $user (keys %{$args{Systems}}) {
    foreach my $keyword (keys %{$args{Systems}->{$user}}) {
      my $results = {};
      foreach my $sentence (@{$args{Systems}->{$user}{$keyword}}) {
	my $tagged_text = $p->add_tags($sentence);
	# print STDERR "$tagged_text\n";
	my %word_list = $p->get_max_noun_phrases($tagged_text);
	# print STDERR Dumper(\%word_list);
	my $processed = $sentence;
	$processed =~ s/.*?$keyword//sg;
	my $score = {};
	foreach my $word (keys %word_list) {
	  my $qword = shell_quote($word);
	  $qword =~ s/\\/\\\\/sg;
	  $qword =~ s/\(/\\\(/sg;
	  $qword =~ s/\)/\\\)/sg;
	  $qword =~ s/^'//;
	  $qword =~ s/'$//;
	  try {
	    if ($processed =~ /^(.*?)$qword(.*)$/) {
	      $score->{$word} = length($1);
	    }
	  } catch {
	    warn "caught error: $_";
	  };
	}
	my $bestmatch = [sort {$score->{$a} <=> $score->{$b}} keys %$score]->[0];
	if ($bestmatch) {
	  $results->{$sentence} = [$bestmatch];
	}
      }
      foreach my $key (keys %$results) {
	$newresults->{$user}{$keyword}{$key} = $results->{$key};
	$allresults->{$user}{$keyword}{$key} = $results->{$key};
      }
      $args{Systems}->{$user}{$keyword} = [];
    }
  }
  print STDERR Dumper($newresults);
}
