#!/usr/bin/perl -w

use BOSS::Config;
use PerlLib::SwissArmyKnife;

use Lingua::EN::Tagger;

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

my $verbose = 1;

my $title = $conf->{'-t'} || '<REDACTED>';
my $c = read_file("logs/${title}.txt");

my @lines;
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
    print "<$sender> to <$receiver> at <$time>: $line .\n\n" if $verbose > 2;
  }
}

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
    my $sentence =  "<$sender> to <$receiver> at <$time>: $line .";
    print "%% $sentence\n" if $verbose > 2;
    print "sentence('$title',sentenceIdFn($key),".shell_quote($sentence).").\n" if $verbose > 2;
    print "hasFormalization('$title',sentenceIdFn($key),\n" if $verbose > 2;
    print "                 [\n" if $verbose > 2;
    print "                  _\n" if $verbose > 2;
    print "                 ]).\n\n" if $verbose > 2;

    my $jlines = join(" ",map {$_ || ' '} @$lines);
    # print $jlines."\n";
    if ($jlines =~ /I\'ll (\S+)/s) {
      push @{$systems->{$sender}{'I\'ll'}}, $jlines;
    }
    if ($jlines =~ /I (will|should|must|may|ought|shall) (\S+)/s) {
      push @{$systems->{$sender}{'I (will|should|must|may|ought|shall)'}}, $jlines;
    }
  }
  print Dumper($systems);
  # ExtractNamedEntities(Systems => $systems);
}

sub ExtractNamedEntities {
  my (%args) = @_;
  my $p = new Lingua::EN::Tagger;
  my $allresults = {};
  foreach my $user (keys %{$args{Systems}}) {
    foreach my $keyword (keys %{$args{Systems}->{$user}}) {
      my $results = {};
      foreach my $sentence (@{$args{Systems}->{$user}{$keyword}}) {
	my $tagged_text = $p->add_tags($sentence);
	my %word_list = $p->get_max_noun_phrases($tagged_text);
	my $processed = $sentence;
	$processed =~ s/.*?$keyword//sg;
	my $score = {};
	foreach my $word (keys %word_list) {
	  my $qword = shell_quote($word);
	  $qword =~ s/\(/\\\(/sg;
	  $qword =~ s/\)/\\\)/sg;
	  $qword =~ s/\[/\\\[/sg;
	  $qword =~ s/\]/\\\]/sg;
	  $qword =~ s/^'//;
	  $qword =~ s/'$//;
	  if ($processed =~ /^(.*?)$qword(.*)$/) {
	    $score->{$word} = length($1);
	  }
	}
	my $bestmatch = [sort {$score->{$a} <=> $score->{$b}} keys %$score]->[0];
	if ($bestmatch) {
	  $results->{$bestmatch} = $sentence;
	}
      }
      $allresults->{$user}{$keyword} = $results;
    }
  }
  print Dumper({AllResults => $allresults});
}


